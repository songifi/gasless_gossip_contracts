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
