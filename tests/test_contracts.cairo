use contract::interfaces::igossip::{iGossipDispatcher, iGossipDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address};
use starknet::ContractAddress;

fn setup() -> ContractAddress {
    let contract = declare("gossip").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    (contract_address)
}

#[test]
fn test_register_user() {
    let contract_address = setup();
    let Contract = iGossipDispatcher { contract_address };
    let username: felt252 = 'alice';
    let profile_hash: felt252 = 'ipfs://QmProfile123';
    let user_address = 'alice'.try_into().unwrap();

    start_cheat_caller_address(contract_address, user_address);
    // Register user
    Contract.register_user(username, profile_hash);

    // Verify user is registered
    let is_registered = Contract.is_address_registered(user_address);
    assert(is_registered, 'User should be registered');

    // Verify username is taken
    let is_taken = Contract.is_username_taken(username);
    assert(is_taken, 'Username should be taken');

    // Verify address is registered
    let is_registered = Contract.is_address_registered(user_address);
    assert!(is_registered, "User should be registered");
}


#[test]
#[should_panic(expected: 'Username is already taken')]
fn test_duplicate_username() {
    // Setup test
    let contract_address = setup();
    let contract = iGossipDispatcher { contract_address };

    // Test data
    let username: felt252 = 'bob';
    let profile_hash: felt252 = 'ipfs://QmProfile123';

    // Register first user
    let user1_address: ContractAddress = 'bob'.try_into().unwrap();
    start_cheat_caller_address(contract_address, user1_address);
    contract.register_user(username, profile_hash);

    // Try to register second user with same username
    let user2_address: ContractAddress = 'haja'.try_into().unwrap();
    start_cheat_caller_address(contract_address, user2_address);
    contract.register_user(username, profile_hash); // Should panic
}

#[test]
#[should_panic(expected: 'Address already registered')]
fn test_double_registration() {
    // Setup test
    let contract_address = setup();
    let contract = iGossipDispatcher { contract_address };

    // Test data
    let username1: felt252 = 'carol';
    let username2: felt252 = 'dave';
    let profile_hash: felt252 = 'ipfs://QmProfile123';

    // Register user with first username
    let user_address: ContractAddress = 'haja'.try_into().unwrap();
    start_cheat_caller_address(contract_address, user_address);
    contract.register_user(username1, profile_hash);

    // Try to register same address with different username
    contract.register_user(username2, profile_hash); // Should panic
}

#[test]
fn test_update_profile() {
    // Setup test
    let contract_address = setup();
    let contract = iGossipDispatcher { contract_address };

    // Test data
    let username: felt252 = 'eve';
    let profile_hash1: felt252 = 'ipfs://QmProfile123';
    let profile_hash2: felt252 = 'ipfs://QmProfile456';

    // Register user
    let user_address: ContractAddress = 'hajiya'.try_into().unwrap();
    start_cheat_caller_address(contract_address, user_address);
    contract.register_user(username, profile_hash1);

    //Get the profile hash
    let retrieved_profile_hash = contract.get_profile_hash(user_address);
    assert!(retrieved_profile_hash == profile_hash1, "Profile hash mismatch");

    // Update profile
    contract.update_profile(profile_hash2);

    // Verify profile is updated
    let updated_profile_hash = contract.get_profile_hash(user_address);
    assert!(updated_profile_hash == profile_hash2, "Profile hash not updated");
}

// Test username lookup
#[test]
fn test_username_lookup() {
    // Setup test
    let contract_address = setup();
    let contract = iGossipDispatcher { contract_address };

    // Register user
    let username: felt252 = 'alice';
    let profile_hash: felt252 = 'ipfs://QmProfile123';
    let user_address: ContractAddress = 'alice'.try_into().unwrap();
    start_cheat_caller_address(contract_address, user_address);
    contract.register_user(username, profile_hash);

    // Check if username is taken
    let is_taken = contract.is_username_taken(username);
    assert(is_taken, 'Username should be taken');

    // Check if a different username is available
    let different_username: felt252 = 'bob';
    let is_different_taken = contract.is_username_taken(different_username);
    assert(!is_different_taken, 'Different username shoul taken');
}

// Test multiple users registration
#[test]
fn test_multiple_users() {
    // Setup test
    let contract_address = setup();
    let contract = iGossipDispatcher { contract_address };

    // Register first user
    let username1: felt252 = 'alice';
    let profile_hash1: felt252 = 'ipfs://QmProfile123';
    let user_address1: ContractAddress = 'alice'.try_into().unwrap();
    start_cheat_caller_address(contract_address, user_address1);
    contract.register_user(username1, profile_hash1);

    // Register second user
    let username2: felt252 = 'bob';
    let profile_hash2: felt252 = 'ipfs://QmProfile456';
    let user_address2: ContractAddress = 'bob'.try_into().unwrap();
    start_cheat_caller_address(contract_address, user_address2);
    contract.register_user(username2, profile_hash2);

    // Verify both users are registered
    let is_registered1 = contract.is_address_registered(user_address1);
    let is_registered2 = contract.is_address_registered(user_address2);
    assert(is_registered1, 'First user should be registered');
    assert(is_registered2, 'Second user should e registered');
}

// Test profile hash retrieval
#[test]
fn test_profile_hash_retrieval() {
    // Setup test
    let contract_address = setup();
    let contract = iGossipDispatcher { contract_address };

    // Register user
    let username: felt252 = 'carol';
    let profile_hash: felt252 = 'ipfs://QmProfileCarol';
    let user_address: ContractAddress = 'carol'.try_into().unwrap();
    start_cheat_caller_address(contract_address, user_address);
    contract.register_user(username, profile_hash);

    // Verify profile hash
    let retrieved_hash = contract.get_profile_hash(user_address);
    assert(retrieved_hash == profile_hash, 'Profile hash mismatch');
}

// Test non-registered address
#[test]
fn test_non_registered_address() {
    // Setup test
    let contract_address = setup();
    let contract = iGossipDispatcher { contract_address };

    // Check non-registered address
    let non_registered: ContractAddress = 'nonexistent'.try_into().unwrap();
    let is_registered = contract.is_address_registered(non_registered);
    assert(!is_registered, 'Address should not  registered');
}


// Test profile update verification
#[test]
fn test_profile_update_verification() {
    // Setup test
    let contract_address = setup();
    let contract = iGossipDispatcher { contract_address };

    // Register user
    let username: felt252 = 'diana';
    let initial_profile: felt252 = 'ipfs://QmInitialProfile';
    let updated_profile: felt252 = 'ipfs://QmUpdatedProfile';
    let user_address: ContractAddress = 'diana'.try_into().unwrap();

    // Register with initial profile
    start_cheat_caller_address(contract_address, user_address);
    contract.register_user(username, initial_profile);

    // Verify initial profile
    let profile_before = contract.get_profile_hash(user_address);
    assert(profile_before == initial_profile, 'Initial profile mismatch');

    // Update profile
    contract.update_profile(updated_profile);

    // Verify updated profile
    let profile_after = contract.get_profile_hash(user_address);
    assert(profile_after == updated_profile, 'Updated profile mismatch');
    assert(profile_after != initial_profile, 'Profile not changed');
}

// Test concurrent registrations
#[test]
fn test_concurrent_registrations() {
    // Setup test
    let contract_address = setup();
    let contract = iGossipDispatcher { contract_address };

    // Create multiple users with unique usernames
    let users = array![
        ('user1', 'eric', 'ipfs://QmProfileEric'),
        ('user2', 'fiona', 'ipfs://QmProfileFiona'),
        ('user3', 'george', 'ipfs://QmProfileGeorge'),
    ];

    // Register all users
    let mut i = 0;
    loop {
        if i >= users.len() {
            break;
        }

        let (addr_str, username, profile) = *users.at(i);
        let user_address: ContractAddress = addr_str.try_into().unwrap();
        start_cheat_caller_address(contract_address, user_address);
        contract.register_user(username, profile);

        i += 1;
    }

    // Verify all users are registered
    i = 0;
    loop {
        if i >= users.len() {
            break;
        }

        let (addr_str, username, _) = *users.at(i);
        let user_address: ContractAddress = addr_str.try_into().unwrap();

        let is_registered = contract.is_address_registered(user_address);
        assert(is_registered, 'User should be registered');

        i += 1;
    }
}

// Test case sensitivity of usernames (if applicable)
#[test]
fn test_username_case_sensitivity() {
    // Setup test
    let contract_address = setup();
    let contract = iGossipDispatcher { contract_address };

    // Register with lowercase username
    let lowercase_username: felt252 = 'hannah';
    let profile_hash: felt252 = 'ipfs://QmProfile123';
    let user_address: ContractAddress = 'hannah'.try_into().unwrap();
    start_cheat_caller_address(contract_address, user_address);
    contract.register_user(lowercase_username, profile_hash);

    // Check if uppercase version is considered taken
    // Note: This test assumes felt252 preserves case sensitivity
    // If your contract treats uppercase/lowercase as same, this test would fail
    let uppercase_username: felt252 = 'HANNAH';
    let is_taken = contract.is_username_taken(uppercase_username);

    // This assertion depends on your contract's behavior:
    // If usernames are case-sensitive, uppercase should not be taken
    // If usernames are case-insensitive, uppercase should be taken
    assert(!is_taken, 'Uppercase should be  lowercase');
}

// Test updating profile hash multiple times
#[test]
fn test_multiple_profile_updates() {
    // Setup test
    let contract_address = setup();
    let contract = iGossipDispatcher { contract_address };

    // Register user
    let username: felt252 = 'isaac';
    let initial_profile: felt252 = 'ipfs://QmInitialProfile';
    let user_address: ContractAddress = 'isaac'.try_into().unwrap();

    start_cheat_caller_address(contract_address, user_address);
    contract.register_user(username, initial_profile);

    // Update profile hash multiple times
    let profile_updates = array!['ipfs://QmProfile1', 'ipfs://QmProfile2', 'ipfs://QmProfile3'];

    let mut i = 0;
    loop {
        if i >= profile_updates.len() {
            break;
        }

        let new_profile = *profile_updates.at(i);
        contract.update_profile(new_profile);

        // Verify update
        let current_profile = contract.get_profile_hash(user_address);
        assert(current_profile == new_profile, 'Profile update failed');

        i += 1;
    }

    // Verify final state
    let final_profile = contract.get_profile_hash(user_address);
    assert(
        final_profile == *profile_updates.at(profile_updates.len() - 1), 'Final profile mismatch',
    );
}

// Test registration status after profile update
#[test]
fn test_registration_status_after_update() {
    // Setup test
    let contract_address = setup();
    let contract = iGossipDispatcher { contract_address };

    // Register user
    let username: felt252 = 'julia';
    let initial_profile: felt252 = 'ipfs://QmInitialProfile';
    let updated_profile: felt252 = 'ipfs://QmUpdatedProfile';
    let user_address: ContractAddress = 'julia'.try_into().unwrap();

    start_cheat_caller_address(contract_address, user_address);
    contract.register_user(username, initial_profile);

    // Update profile
    contract.update_profile(updated_profile);

    // Verify user is still registered
    let is_registered = contract.is_address_registered(user_address);
    assert(is_registered, 'User should still be rupdate');

    // Verify username is still taken
    let is_taken = contract.is_username_taken(username);
    assert(is_taken, 'Username should after update');
}


//Test many registrations to check scalability
#[test]
fn test_many_registrations() {
    // Setup test
    let contract_address = setup();
    let contract = iGossipDispatcher { contract_address };

    // Register multiple users (10 in this example)
    let num_users: u32 = 10;
    let mut i: u32 = 0;

    while i < num_users {
        // Create unique username and address
        // Note: This is a simplistic way to create unique values
        let username: felt252 = 'user'.into() + i.into();
        let profile_hash: felt252 = 'ipfs://QmProfile'.into() + i.into();
        let addr_str: felt252 = ('addr'.into() + i.into()) * 1;
        let user_address: ContractAddress = addr_str.try_into().unwrap();

        start_cheat_caller_address(contract_address, user_address);
        contract.register_user(username, profile_hash);

        // Verify registration succeeded
        let is_registered = contract.is_address_registered(user_address);
        assert(is_registered, 'User should be registered');

        i += 1;
    }
}

