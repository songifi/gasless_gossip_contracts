

use contract::interfaces::igossip::{iGossipDispatcher, iGossipDispatcherTrait};
use contract::interfaces::igroupchat::{IGroupChatDispatcher, IGroupChatDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address};
use starknet::ContractAddress;

// Setup function for tests
fn setup() -> (ContractAddress, ContractAddress) {
    // First deploy the user registry (gossip) contract
    let registry_contract = declare("gossip").unwrap().contract_class();
    let (registry_address, _) = registry_contract.deploy(@array![]).unwrap();

    // Then deploy the group chat contract with the registry address
    let group_contract = declare("GroupChat").unwrap().contract_class();
    let constructor_args = array![registry_address.into()];
    let (group_address, _) = group_contract.deploy(@constructor_args).unwrap();

    (registry_address, group_address)
}

// Helper to register users in the gossip contract
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
fn test_create_group() {
    // Setup
    let (registry_address, group_address) = setup();
    let group_contract = IGroupChatDispatcher { contract_address: group_address };
    
    // Register a user
    let admin_address: ContractAddress = 'admin'.try_into().unwrap();
    let admin_username: felt252 = 'admin_user';
    let profile_hash: felt252 = 'ipfs://QmAdminProfile';
    register_user(registry_address, admin_address, admin_username, profile_hash);
    
    // Create a group
    start_cheat_caller_address(group_address, admin_address);
    let metadata_uri: felt252 = 'ipfs://QmGroupMetadata';
    let group_id = group_contract.create_group(metadata_uri);
    
    // Verify the group was created
    assert(group_id == 1, 'Group ID should be 1');
    
    // Check group metadata
    let stored_metadata = group_contract.get_group_metadata(group_id);
    assert(stored_metadata == metadata_uri, 'Metadata mismatch');
    
    // Check admin
    let stored_admin = group_contract.get_group_admin(group_id);
    assert(stored_admin == admin_address, 'Admin mismatch');
    
    // Check membership
    let is_member = group_contract.is_group_member(group_id, admin_address);
    assert(is_member, 'Admin should be a member');
    
    // Check members count
    let members_count = group_contract.get_members_count(group_id);
    assert(members_count == 1, 'Members count should be 1');
}

#[test]
fn test_add_member() {
    // Setup
    let (registry_address, group_address) = setup();
    let group_contract = IGroupChatDispatcher { contract_address: group_address };
    
    // Register admin
    let admin_address: ContractAddress = 'admin'.try_into().unwrap();
    register_user(registry_address, admin_address, 'admin_user', 'ipfs://QmAdminProfile');
    
    // Register member
    let member_address: ContractAddress = 'member'.try_into().unwrap();
    register_user(registry_address, member_address, 'member_user', 'ipfs://QmMemberProfile');
    
    // Create a group
    start_cheat_caller_address(group_address, admin_address);
    let group_id = group_contract.create_group('ipfs://QmGroupMetadata');
    
    // Add member
    group_contract.add_member(group_id, member_address);
    
    // Verify member was added
    let is_member = group_contract.is_group_member(group_id, member_address);
    assert(is_member, 'User should be a member');
    
    // Check members count
    let members_count = group_contract.get_members_count(group_id);
    assert(members_count == 2, 'Members count should be 2');
    
    // Check from member's perspective
    let is_in_group = group_contract.is_user_in_group(member_address, group_id);
    assert(is_in_group, 'User should be in group');
}

#[test]
#[should_panic(expected: 'Address is already a member')]
fn test_add_duplicate_member() {
    // Setup
    let (registry_address, group_address) = setup();
    let group_contract = IGroupChatDispatcher { contract_address: group_address };
    
    // Register admin
    let admin_address: ContractAddress = 'admin'.try_into().unwrap();
    register_user(registry_address, admin_address, 'admin_user', 'ipfs://QmAdminProfile');
    
    // Register member
    let member_address: ContractAddress = 'member'.try_into().unwrap();
    register_user(registry_address, member_address, 'member_user', 'ipfs://QmMemberProfile');
    
    // Create a group
    start_cheat_caller_address(group_address, admin_address);
    let group_id = group_contract.create_group('ipfs://QmGroupMetadata');
    
    // Add member
    group_contract.add_member(group_id, member_address);
    
    // Try to add the same member again - should panic
    group_contract.add_member(group_id, member_address);
}

#[test]
fn test_remove_member() {
    // Setup
    let (registry_address, group_address) = setup();
    let group_contract = IGroupChatDispatcher { contract_address: group_address };
    
    // Register admin
    let admin_address: ContractAddress = 'admin'.try_into().unwrap();
    register_user(registry_address, admin_address, 'admin_user', 'ipfs://QmAdminProfile');
    
    // Register member
    let member_address: ContractAddress = 'member'.try_into().unwrap();
    register_user(registry_address, member_address, 'member_user', 'ipfs://QmMemberProfile');
    
    // Create a group
    start_cheat_caller_address(group_address, admin_address);
    let group_id = group_contract.create_group('ipfs://QmGroupMetadata');
    
    // Add member
    group_contract.add_member(group_id, member_address);
    
    // Remove member
    group_contract.remove_member(group_id, member_address);
    
    // Verify member was removed
    let is_member = group_contract.is_group_member(group_id, member_address);
    assert(!is_member, 'User should not be a member');
    
    // Check members count
    let members_count = group_contract.get_members_count(group_id);
    assert(members_count == 1, 'Members count should be 1');
}

#[test]
#[should_panic(expected: 'Unauthorized action')]
fn test_remove_admin() {
    // Setup
    let (registry_address, group_address) = setup();
    let group_contract = IGroupChatDispatcher { contract_address: group_address };
    
    // Register admin
    let admin_address: ContractAddress = 'admin'.try_into().unwrap();
    register_user(registry_address, admin_address, 'admin_user', 'ipfs://QmAdminProfile');
    
    // Create a group
    start_cheat_caller_address(group_address, admin_address);
    let group_id = group_contract.create_group('ipfs://QmGroupMetadata');
    
    // Try to remove admin - should panic
    group_contract.remove_member(group_id, admin_address);
}

#[test]
fn test_change_admin() {
    // Setup
    let (registry_address, group_address) = setup();
    let group_contract = IGroupChatDispatcher { contract_address: group_address };
    
    // Register admin
    let admin_address: ContractAddress = 'admin'.try_into().unwrap();
    register_user(registry_address, admin_address, 'admin_user', 'ipfs://QmAdminProfile');
    
    // Register new admin
    let new_admin_address: ContractAddress = 'new_admin'.try_into().unwrap();
    register_user(registry_address, new_admin_address, 'new_admin_user', 'ipfs://QmNewAdminProfile');
    
    // Create a group
    start_cheat_caller_address(group_address, admin_address);
    let group_id = group_contract.create_group('ipfs://QmGroupMetadata');
    
    // Add new admin as a member first
    group_contract.add_member(group_id, new_admin_address);
    
    // Change admin
    group_contract.change_admin(group_id, new_admin_address);
    
    // Verify admin was changed
    let current_admin = group_contract.get_group_admin(group_id);
    assert(current_admin == new_admin_address, 'Admin should be changed');
}

#[test]
#[should_panic(expected: 'Address is not a member')]
fn test_change_admin_non_member() {
    // Setup
    let (registry_address, group_address) = setup();
    let group_contract = IGroupChatDispatcher { contract_address: group_address };
    
    // Register admin
    let admin_address: ContractAddress = 'admin'.try_into().unwrap();
    register_user(registry_address, admin_address, 'admin_user', 'ipfs://QmAdminProfile');
    
    // Register new admin
    let new_admin_address: ContractAddress = 'new_admin'.try_into().unwrap();
    register_user(registry_address, new_admin_address, 'new_admin_user', 'ipfs://QmNewAdminProfile');
    
    // Create a group
    start_cheat_caller_address(group_address, admin_address);
    let group_id = group_contract.create_group('ipfs://QmGroupMetadata');
    
    // Try to change admin to non-member - should panic
    group_contract.change_admin(group_id, new_admin_address);
}

#[test]
#[should_panic(expected: 'User must be registered')]
fn test_unregistered_user_create_group() {
    // Setup
    let (registry_address, group_address) = setup();
    let group_contract = IGroupChatDispatcher { contract_address: group_address };
    
    // Unregistered address
    let unregistered_address: ContractAddress = 'unregistered'.try_into().unwrap();
    
    // Try to create a group with unregistered user - should panic
    start_cheat_caller_address(group_address, unregistered_address);
    group_contract.create_group('ipfs://QmGroupMetadata');
} 

