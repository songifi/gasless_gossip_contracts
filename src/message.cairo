#[starknet::contract]
pub mod MessageStore {
    use contract::interfaces::igossip::{iGossipDispatcher, iGossipDispatcherTrait};
    use core::num::traits::Zero;
    use core::traits::Into;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::base::errors::Errors::{
        ERROR_ADDRESS_REGISTERED, ERROR_EMPTY_CONTENT, ERROR_INVALID_RECEIVER, ERROR_NOT_REGISTERED,
        ERROR_SELF_MESSAGE, ERROR_UNAUTHORIZED, ERROR_USERNAME_LENGTH, ERROR_USERNAME_NOT_FOUND,
        ERROR_USERNAME_TAKEN, ERROR_ZERO_ADDRESS,
    };


    // Import UserRegistry interface for validation
    use crate::interfaces::igossip::iMessage;

    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct Message {
        id: u256,
        sender: ContractAddress,
        receiver: ContractAddress,
        content_hash: felt252,
        timestamp: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        MessageSent: MessageSent,
    }

    #[derive(Drop, starknet::Event)]
    struct MessageSent {
        sender: ContractAddress,
        receiver: ContractAddress,
        content_hash: felt252,
        timestamp: u64,
    }

    #[storage]
    struct Storage {
        // User registry contract address
        user_registry: ContractAddress,
        // Message counter for generating unique IDs
        message_counter: u256,
        // Messages stored by conversation ID and message ID
        // conversation_id = hash(min(user1, user2), max(user1, user2))
        messages: Map<(felt252, u256), Message>,
        // Number of messages in a conversation
        conversation_message_count: Map<felt252, u256>,
        // User's conversations
        user_conversations: Map<ContractAddress, Array<felt252>>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, user_registry_address: ContractAddress) {
        assert(!user_registry_address.is_zero(), ERROR_ZERO_ADDRESS);
        self.user_registry.write(user_registry_address);
        self.message_counter.write(0);
    }

    #[abi(embed_v0)]
    impl MessageStoreImpl of iMessage<ContractState> {
        fn send_message(ref self: ContractState, to: ContractAddress, content_hash: felt252) {
            let sender = get_caller_address();

            // Basic validations
            assert(!sender.is_zero(), ERROR_ZERO_ADDRESS);
            assert(!to.is_zero(), ERROR_ZERO_ADDRESS);
            assert(sender != to, ERROR_SELF_MESSAGE);
            assert(content_hash != 0, ERROR_EMPTY_CONTENT);

            // Check that both sender and receiver are registered users
            let user_registry = iGossipDispatcher { contract_address: self.user_registry.read() };
            assert(user_registry.is_address_registered(sender), ERROR_NOT_REGISTERED);
            assert(user_registry.is_address_registered(to), ERROR_INVALID_RECEIVER);

            // Generate conversation ID and get message count
            let conversation_id = private::generate_conversation_id(sender, to);
            let mut message_count = self.conversation_message_count.read(conversation_id);

            // Create and store the message
            let timestamp = get_block_timestamp();
            let message_id = self.message_counter.read();

            let message = Message {
                id: message_id,
                sender: sender,
                receiver: to,
                content_hash: content_hash,
                timestamp: timestamp,
            };

            // Store message in the conversation
            self.messages.write((conversation_id, message_count), message);

            // Update counters
            self.conversation_message_count.write(conversation_id, message_count + 1);
            self.message_counter.write(message_id + 1);

            // Emit event
            self
                .emit(
                    Event::MessageSent(
                        MessageSent {
                            sender: sender,
                            receiver: to,
                            content_hash: content_hash,
                            timestamp: timestamp,
                        },
                    ),
                );
        }


        fn get_messages_between(
            self: @ContractState, user1: ContractAddress, user2: ContractAddress,
        ) -> Array<Message> {
            let caller = get_caller_address();

            // Ensure caller is either user1 or user2
            assert(caller == user1 || caller == user2, ERROR_UNAUTHORIZED);

            // Generate conversation ID
            let conversation_id = private::generate_conversation_id(user1, user2);
            let message_count = self.conversation_message_count.read(conversation_id);

            // Retrieve all messages
            let mut messages = ArrayTrait::new();
            let mut i: u256 = 0;

            while i < message_count {
                let message = self.messages.read((conversation_id, i));
                messages.append(message);
                i += 1;
            }

            messages
        }


        // Get the count of messages between two users
        fn get_message_count(
            self: @ContractState, user1: ContractAddress, user2: ContractAddress,
        ) -> u256 {
            let caller = get_caller_address();

            // Ensure caller is either user1 or user2
            assert(caller == user1 || caller == user2, ERROR_UNAUTHORIZED);

            // Generate conversation ID and return count
            let conversation_id = private::generate_conversation_id(user1, user2);
            self.conversation_message_count.read(conversation_id)
        }


        // Get a specific message by its index in a conversation
        fn get_message_at_index(
            self: @ContractState, user1: ContractAddress, user2: ContractAddress, index: u256,
        ) -> Message {
            let caller = get_caller_address();

            // Ensure caller is either user1 or user2
            assert(caller == user1 || caller == user2, ERROR_UNAUTHORIZED);

            // Generate conversation ID
            let conversation_id = private::generate_conversation_id(user1, user2);
            let message_count = self.conversation_message_count.read(conversation_id);

            // Ensure index is valid
            assert(index < message_count, 'Invalid message index');

            // Return the message at the specified index
            self.messages.read((conversation_id, index))
        }

        // Get the user registry address
        fn get_user_registry(self: @ContractState) -> ContractAddress {
            self.user_registry.read()
        }
    }


    #[generate_trait]
    impl private of PrivateTrait {
        // Generate a unique conversation ID from two addresses
        fn generate_conversation_id(addr1: ContractAddress, addr2: ContractAddress) -> felt252 {
            // Convert addresses to felt252
            let addr1_felt: felt252 = addr1.into();
            let addr2_felt: felt252 = addr2.into();

            // Convert to u256 for comparison
            let addr1_u256 = u256 { low: addr1_felt.try_into().unwrap(), high: 0 };
            let addr2_u256 = u256 { low: addr2_felt.try_into().unwrap(), high: 0 };

            // Ensure consistent ordering
            let (first, second) = if addr1_u256 < addr2_u256 {
                (addr1_felt, addr2_felt)
            } else {
                (addr2_felt, addr1_felt)
            };

            // Simple hash combining technique
            first * 3600502366235663291 + second
        }
    }
}
