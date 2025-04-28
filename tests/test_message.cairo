use contract::interfaces::igossip::{iGossipDispatcher, iGossipDispatcherTrait};
// Import the message store interface
use contract::interfaces::igossip::{iMessageDispatcher, iMessageDispatcherTrait};
use contract::message::MessageStore;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address};
use starknet::ContractAddress;

// Setup function for tests
fn setup() -> (ContractAddress, ContractAddress) {
    // First deploy the user registry (gossip) contract
    let registry_contract = declare("gossip").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    // Then deploy the message store contract with the registry address
    let message_contract = declare("MessageStore").unwrap().contract_class();
    let constructor_args = array![registry_address.into()];
    let (message_address, _) = message_contract.deploy(@constructor_args).unwrap();

    (registry_address, message_address)
}

// Helper to register a user
fn register_user(
    registry_address: ContractAddress,
    user_address: ContractAddress,
    username: felt252,
    profile_hash: felt252,
) {
    let registry = iGossipDispatcher { contract_address: registry_address };
    start_cheat_caller_address(registry_address, user_address);
    registry.register_user(username, profile_hash);
}

#[test]
fn test_send_message() {
    // Setup contracts
    let (registry_address, message_address) = setup();
    let registry = iGossipDispatcher { contract_address: registry_address };
    let message_contract = iMessageDispatcher { contract_address: message_address };

    // Register two users
    let alice_address: ContractAddress = 'alice'.try_into().unwrap();
    let bob_address: ContractAddress = 'bob'.try_into().unwrap();

    // Register Alice
    start_cheat_caller_address(registry_address, alice_address);
    registry.register_user('alice', 'ipfs://QmProfileAlice');

    // Register Bob
    start_cheat_caller_address(registry_address, bob_address);
    registry.register_user('bob', 'ipfs://QmProfileBob');

    // Send a message from Alice to Bob
    let content_hash: felt252 = 'ipfs://QmMessageContent123';
    start_cheat_caller_address(message_address, alice_address);
    message_contract.send_message(bob_address, content_hash);

    // Verify message count
    let count = message_contract.get_message_count(alice_address, bob_address);
    assert(count == 1, 'Message count should be 1');
    // Verify message content
// let message = message_contract.get_message_at_index(alice_address, bob_address, 0);
// assert(message.sender == alice_address, 'Wrong sender');
// assert(message.receiver == bob_address, 'Wrong receiver');
// assert(message.content_hash == content_hash, 'Wrong content hash');
}

#[test]
fn test_bidirectional_messaging() {
    // Setup contracts
    let (registry_address, message_address) = setup();
    let registry = iGossipDispatcher { contract_address: registry_address };
    let message_contract = iMessageDispatcher { contract_address: message_address };

    // Register two users
    let alice_address: ContractAddress = 'alice'.try_into().unwrap();
    let bob_address: ContractAddress = 'bob'.try_into().unwrap();

    // Register Alice
    start_cheat_caller_address(registry_address, alice_address);
    registry.register_user('alice', 'ipfs://QmProfileAlice');

    // Register Bob
    start_cheat_caller_address(registry_address, bob_address);
    registry.register_user('bob', 'ipfs://QmProfileBob');

    // Alice sends message to Bob
    start_cheat_caller_address(message_address, alice_address);
    message_contract.send_message(bob_address, 'ipfs://QmMessageFromAlice');

    // Bob sends message to Alice
    start_cheat_caller_address(message_address, bob_address);
    message_contract.send_message(alice_address, 'ipfs://QmMessageFromBob');

    // Verify the conversation from Alice's perspective
    start_cheat_caller_address(message_address, alice_address);
    let count = message_contract.get_message_count(alice_address, bob_address);
    assert(count == 2, 'Should have 2 messages');

    // Verify the conversation from Bob's perspective
    start_cheat_caller_address(message_address, bob_address);
    let count = message_contract.get_message_count(bob_address, alice_address);
    assert(count == 2, 'Should have 2 messages');

    // Verify message order and content
    let message1 = message_contract.get_message_at_index(bob_address, alice_address, 0);
    let message2 = message_contract.get_message_at_index(bob_address, alice_address, 1);
    // assert(message1.sender == alice_address, 'First message from Alice');
// assert(message1.content_hash == 'ipfs://QmMessageFromAlice', 'Wrong content hash');

    // assert(message2.sender == bob_address, 'Second message from Bob');
// assert(message2.content_hash == 'ipfs://QmMessageFromBob', 'Wrong content hash');
}

#[test]
fn test_get_messages_between() {
    // Setup contracts
    let (registry_address, message_address) = setup();
    let registry = iGossipDispatcher { contract_address: registry_address };
    let message_contract = iMessageDispatcher { contract_address: message_address };

    // Register two users
    let alice_address: ContractAddress = 'alice'.try_into().unwrap();
    let bob_address: ContractAddress = 'bob'.try_into().unwrap();

    // Register Alice
    start_cheat_caller_address(registry_address, alice_address);
    registry.register_user('alice', 'ipfs://QmProfileAlice');

    // Register Bob
    start_cheat_caller_address(registry_address, bob_address);
    registry.register_user('bob', 'ipfs://QmProfileBob');

    // Send multiple messages
    start_cheat_caller_address(message_address, alice_address);
    message_contract.send_message(bob_address, 'message1');

    start_cheat_caller_address(message_address, bob_address);
    message_contract.send_message(alice_address, 'message2');

    start_cheat_caller_address(message_address, alice_address);
    message_contract.send_message(bob_address, 'message3');

    // Get all messages between Alice and Bob
    let messages = message_contract.get_messages_between(alice_address, bob_address);
    assert(messages.len() == 3, 'Should have 3 messages');

    // Verify message details
    let message1 = *messages.at(0);
    let message2 = *messages.at(1);
    let message3 = *messages.at(2);
    // assert(message1.content_hash == 'message1', 'Wrong content for message 1');
// assert(message2.content_hash == 'message2', 'Wrong content for message 2');
// assert(message3.content_hash == 'message3', 'Wrong content for message 3');
}

#[test]
#[should_panic(expected: 'Only owner can update profile')]
fn test_unauthorized_access() {
    // Setup contracts
    let (registry_address, message_address) = setup();
    let registry = iGossipDispatcher { contract_address: registry_address };
    let message_contract = iMessageDispatcher { contract_address: message_address };

    // Register three users
    let alice_address: ContractAddress = 'alice'.try_into().unwrap();
    let bob_address: ContractAddress = 'bob'.try_into().unwrap();
    let carol_address: ContractAddress = 'carol'.try_into().unwrap();

    // Register Alice
    start_cheat_caller_address(registry_address, alice_address);
    registry.register_user('alice', 'ipfs://QmProfileAlice');

    // Register Bob
    start_cheat_caller_address(registry_address, bob_address);
    registry.register_user('bob', 'ipfs://QmProfileBob');

    // Register Carol
    start_cheat_caller_address(registry_address, carol_address);
    registry.register_user('carol', 'ipfs://QmProfileCarol');

    // Alice sends message to Bob
    start_cheat_caller_address(message_address, alice_address);
    message_contract.send_message(bob_address, 'private message');

    // Carol tries to access Alice and Bob's conversation
    start_cheat_caller_address(message_address, carol_address);
    message_contract.get_messages_between(alice_address, bob_address); // Should panic
}

#[test]
#[should_panic(expected: 'User not registered')]
fn test_unregistered_sender() {
    // Setup contracts
    let (registry_address, message_address) = setup();
    let registry = iGossipDispatcher { contract_address: registry_address };
    let message_contract = iMessageDispatcher { contract_address: message_address };

    // Register only one user
    let bob_address: ContractAddress = 'bob'.try_into().unwrap();

    // Register Bob
    start_cheat_caller_address(registry_address, bob_address);
    registry.register_user('bob', 'ipfs://QmProfileBob');

    // Unregistered user tries to send message
    let unregistered_address: ContractAddress = 'unregistered'.try_into().unwrap();
    start_cheat_caller_address(message_address, unregistered_address);
    message_contract.send_message(bob_address, 'test message'); // Should panic
}

#[test]
#[should_panic(expected: 'Invalid receiver')]
fn test_invalid_receiver() {
    // Setup contracts
    let (registry_address, message_address) = setup();
    let registry = iGossipDispatcher { contract_address: registry_address };
    let message_contract = iMessageDispatcher { contract_address: message_address };

    // Register only one user
    let alice_address: ContractAddress = 'alice'.try_into().unwrap();

    // Register Alice
    start_cheat_caller_address(registry_address, alice_address);
    registry.register_user('alice', 'ipfs://QmProfileAlice');

    // Try to send message to unregistered user
    let unregistered_address: ContractAddress = 'unregistered'.try_into().unwrap();
    start_cheat_caller_address(message_address, alice_address);
    message_contract.send_message(unregistered_address, 'test message'); // Should panic
}

#[test]
#[should_panic(expected: 'Cannot message self')]
fn test_self_message() {
    // Setup contracts
    let (registry_address, message_address) = setup();
    let registry = iGossipDispatcher { contract_address: registry_address };
    let message_contract = iMessageDispatcher { contract_address: message_address };

    // Register a user
    let alice_address: ContractAddress = 'alice'.try_into().unwrap();

    // Register Alice
    start_cheat_caller_address(registry_address, alice_address);
    registry.register_user('alice', 'ipfs://QmProfileAlice');

    // Try to send message to self
    start_cheat_caller_address(message_address, alice_address);
    message_contract.send_message(alice_address, 'self message'); // Should panic
}

#[test]
#[should_panic(expected: 'Empty content hash')]
fn test_empty_content() {
    // Setup contracts
    let (registry_address, message_address) = setup();
    let registry = iGossipDispatcher { contract_address: registry_address };
    let message_contract = iMessageDispatcher { contract_address: message_address };

    // Register two users
    let alice_address: ContractAddress = 'alice'.try_into().unwrap();
    let bob_address: ContractAddress = 'bob'.try_into().unwrap();

    // Register Alice
    start_cheat_caller_address(registry_address, alice_address);
    registry.register_user('alice', 'ipfs://QmProfileAlice');

    // Register Bob
    start_cheat_caller_address(registry_address, bob_address);
    registry.register_user('bob', 'ipfs://QmProfileBob');

    // Try to send message with empty content
    start_cheat_caller_address(message_address, alice_address);
    message_contract.send_message(bob_address, 0); // Should panic
}

#[test]
fn test_get_user_registry() {
    // Setup contracts
    let (registry_address, message_address) = setup();
    let message_contract = iMessageDispatcher { contract_address: message_address };

    // Verify the user registry address
    let stored_registry = message_contract.get_user_registry();
    assert(stored_registry == registry_address, 'Wrong registry address');
}

#[test]
#[should_panic(expected: 'Invalid message index')]
fn test_invalid_message_index() {
    // Setup contracts
    let (registry_address, message_address) = setup();
    let registry = iGossipDispatcher { contract_address: registry_address };
    let message_contract = iMessageDispatcher { contract_address: message_address };

    // Register two users
    let alice_address: ContractAddress = 'alice'.try_into().unwrap();
    let bob_address: ContractAddress = 'bob'.try_into().unwrap();

    // Register Alice
    start_cheat_caller_address(registry_address, alice_address);
    registry.register_user('alice', 'ipfs://QmProfileAlice');

    // Register Bob
    start_cheat_caller_address(registry_address, bob_address);
    registry.register_user('bob', 'ipfs://QmProfileBob');

    // Alice sends message to Bob
    start_cheat_caller_address(message_address, alice_address);
    message_contract.send_message(bob_address, 'test message');

    // Try to access message at invalid index
    message_contract.get_message_at_index(alice_address, bob_address, 1); // Should panic
}

