#[starknet::contract]
pub mod gossip {
    // Imports
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use crate::base::errors::Errors::{
        ERROR_ADDRESS_REGISTERED, ERROR_NOT_REGISTERED, ERROR_USERNAME_LENGTH,
        ERROR_USERNAME_NOT_FOUND, ERROR_USERNAME_TAKEN, ERROR_ZERO_ADDRESS,
    };
    use crate::interfaces::igossip::iGossip;

    // User struct
    #[derive(Drop, Serde, PartialEq, starknet::Store, Clone)]
    pub struct User {
        username: felt252, // Username (unique)
        profile_hash: felt252, // IPFS hash or similar for avatar/bio
        timestamp: u64 // Registration timestamp
    }

    // Storage - IMPORTANT: Must match the storage layout in the proxy
    #[storage]
    struct Storage {
        // Proxy contract fields (must be maintained even if not used directly)
        implementation_hash: starknet::class_hash::ClassHash,
        admin: ContractAddress,
        // Original contract storage
        username_to_address: Map<felt252, ContractAddress>,
        address_to_user: Map<ContractAddress, User>,
        is_registered: Map<ContractAddress, bool>,
    }

    // Constants for username constraints
    const MIN_USERNAME_LENGTH: u8 = 3;
    const MAX_USERNAME_LENGTH: u8 = 32;

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UserRegistered: UserRegistered,
        ProfileUpdated: ProfileUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct UserRegistered {
        address: ContractAddress,
        username: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct ProfileUpdated {
        address: ContractAddress,
        new_profile_hash: felt252,
    }

    // No constructor in implementation contract
    // The state is maintained by the proxy

    #[abi(embed_v0)]
    impl gossipIml of iGossip<ContractState> {
        // Register a new user with a unique username and profile hash
        fn register_user(ref self: ContractState, username: felt252, profile_hash: felt252) {
            let caller = get_caller_address();

            // Validate caller address
            assert(!caller.is_zero(), ERROR_ZERO_ADDRESS);

            // Validate username length (approximate check since felt252 doesn't have direct length)
            // A more precise check would be implemented for production
            assert(username != 0, ERROR_USERNAME_LENGTH);

            // Check if username is already taken
            let existing_address = self.username_to_address.read(username);
            assert(existing_address.is_zero(), ERROR_USERNAME_TAKEN);

            // Check if address is already registered
            let existing_user = self.address_to_user.read(caller);
            assert(existing_user.username.is_zero(), ERROR_ADDRESS_REGISTERED);

            // Create and store new user
            let timestamp = get_block_timestamp();
            let new_user = User {
                username: username, profile_hash: profile_hash, timestamp: timestamp,
            };

            self.address_to_user.write(caller, new_user);
            self.username_to_address.write(username, caller);
            // Emit event
            self
                .emit(
                    Event::UserRegistered(UserRegistered { address: caller, username: username }),
                );
        }

        // Update profile hash for an existing user
        fn update_profile(ref self: ContractState, new_profile_hash: felt252) {
            let caller = get_caller_address();

            // Ensure user exists
            let mut user = self.address_to_user.read(caller);
            assert(!user.username.is_zero(), ERROR_NOT_REGISTERED);

            // Update profile hash
            user.profile_hash = new_profile_hash;
            user.timestamp = get_block_timestamp();
            self.address_to_user.write(caller, user);
            // Emit event
            self
                .emit(
                    Event::ProfileUpdated(
                        ProfileUpdated { address: caller, new_profile_hash: new_profile_hash },
                    ),
                );
        }
        //Get user information by address
        fn get_user_by_address(self: @ContractState, address: ContractAddress) -> User {
            let user = self.address_to_user.read(address);
            assert(!user.username.is_zero(), ERROR_NOT_REGISTERED);
            user
        }


        // Get address by username
        fn get_address_by_username(self: @ContractState, username: felt252) -> ContractAddress {
            let address = self.username_to_address.read(username);
            assert(!address.is_zero(), ERROR_USERNAME_NOT_FOUND);
            address
        }

        // Check if username exists
        fn is_username_taken(ref self: ContractState, username: felt252) -> bool {
            let address = self.username_to_address.read(username);
            !address.is_zero()
        }

        // Check if address is registered
        fn is_address_registered(ref self: ContractState, address: ContractAddress) -> bool {
            let user = self.address_to_user.read(address);
            !user.username.is_zero()
        }

        // Get just the profile hash for a user by address
        fn get_profile_hash(self: @ContractState, address: ContractAddress) -> felt252 {
            let user = self.address_to_user.read(address);
            assert(!user.username.is_zero(), ERROR_NOT_REGISTERED);
            user.profile_hash
        }
    }
}
