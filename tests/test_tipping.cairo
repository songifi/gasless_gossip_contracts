use contract::interfaces::igossip::{iGossipDispatcher, iGossipDispatcherTrait};
use contract::interfaces::itipping::{ITippingDispatcher, ITippingDispatcherTrait};
use contract::interfaces::ierc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use contract::mock_erc20::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address, stop_cheat_caller_address
};
use starknet::ContractAddress;

// Setup function for tests
fn setup() -> (ContractAddress, ContractAddress, ContractAddress) {
    // Deploy Gossip contract
    let gossip_contract = declare("gossip").unwrap().contract_class();
    let (gossip_address, _) = gossip_contract.deploy(@array![]).unwrap();
    
    // Deploy Tipping contract
    let tipping_contract = declare("tipping").unwrap().contract_class();
    let (tipping_address, _) = tipping_contract.deploy(@array![gossip_address.into()]).unwrap();
    
    // Deploy Mock ERC20 token
    let mock_token_contract = declare("MockERC20").unwrap().contract_class();
    let initial_supply = u256 { low: 1000000, high: 0 }; // 1,000,000 tokens
    let owner_address: ContractAddress = 'owner'.try_into().unwrap();
    
    // Create constructor args as felt252
    let name: felt252 = 'TestToken';
    let symbol: felt252 = 'TEST';
    // Convert to felt252
    let supply_low: felt252 = initial_supply.low.try_into().unwrap();
    let supply_high: felt252 = initial_supply.high.try_into().unwrap();
    let owner_felt: felt252 = owner_address.into();
    
    let constructor_calldata = array![name, symbol, supply_low, supply_high, owner_felt];
    let (token_address, _) = mock_token_contract.deploy(@constructor_calldata).unwrap();
    
    // Set token contract in Tipping contract
    let tipping = ITippingDispatcher { contract_address: tipping_address };
    start_cheat_caller_address(tipping_address, owner_address);
    tipping.set_token_contract(token_address);
    stop_cheat_caller_address(tipping_address);
    
    (gossip_address, tipping_address, token_address)
}

#[test]
fn test_tip_user() {
    // Setup
    let (gossip_address, tipping_address, token_address) = setup();
    
    let gossip = iGossipDispatcher { contract_address: gossip_address };
    let tipping = ITippingDispatcher { contract_address: tipping_address };
    let token = IERC20Dispatcher { contract_address: token_address };
    let mock_token = IMockERC20Dispatcher { contract_address: token_address };
    
    // Create users
    let alice: ContractAddress = 'alice'.try_into().unwrap();
    let bob: ContractAddress = 'bob'.try_into().unwrap();
    
    // Register Alice
    start_cheat_caller_address(gossip_address, alice);
    gossip.register_user('alice', 'ipfs://alice_profile');
    stop_cheat_caller_address(gossip_address);
    
    // Register Bob
    start_cheat_caller_address(gossip_address, bob);
    gossip.register_user('bob', 'ipfs://bob_profile');
    stop_cheat_caller_address(gossip_address);
    
    // Mint tokens to Alice
    let owner_address: ContractAddress = 'owner'.try_into().unwrap();
    start_cheat_caller_address(token_address, owner_address);
    let alice_tokens = u256 { low: 1000, high: 0 }; // 1,000 tokens
    mock_token.mint(alice, alice_tokens);
    stop_cheat_caller_address(token_address);
    
    // Alice approves Tipping contract to spend tokens
    start_cheat_caller_address(token_address, alice);
    token.approve(tipping_address, alice_tokens);
    stop_cheat_caller_address(token_address);
    
    // Alice tips Bob
    let tip_amount = u256 { low: 100, high: 0 }; // 100 tokens
    start_cheat_caller_address(tipping_address, alice);
    tipping.tip_user(bob, tip_amount);
    stop_cheat_caller_address(tipping_address);
    
    // Check balances
    let alice_balance = token.balance_of(alice);
    let bob_balance = token.balance_of(bob);
    
    assert(alice_balance == alice_tokens - tip_amount, 'Alice balance incorrect');
    assert(bob_balance == tip_amount, 'Bob balance incorrect');
}

#[test]
#[should_panic(expected: 'User not registered')]
fn test_tip_unregistered_user() {
    // Setup
    let (gossip_address, tipping_address, token_address) = setup();
    
    let gossip = iGossipDispatcher { contract_address: gossip_address };
    let tipping = ITippingDispatcher { contract_address: tipping_address };
    let token = IERC20Dispatcher { contract_address: token_address };
    let mock_token = IMockERC20Dispatcher { contract_address: token_address };
    
    // Create users
    let alice: ContractAddress = 'alice'.try_into().unwrap();
    let unregistered: ContractAddress = 'unregistered'.try_into().unwrap();
    
    // Register Alice
    start_cheat_caller_address(gossip_address, alice);
    gossip.register_user('alice', 'ipfs://alice_profile');
    stop_cheat_caller_address(gossip_address);
    
    // Mint tokens to Alice
    let owner_address: ContractAddress = 'owner'.try_into().unwrap();
    start_cheat_caller_address(token_address, owner_address);
    let alice_tokens = u256 { low: 1000, high: 0 }; // 1,000 tokens
    mock_token.mint(alice, alice_tokens);
    stop_cheat_caller_address(token_address);
    
    // Alice approves Tipping contract to spend tokens
    start_cheat_caller_address(token_address, alice);
    token.approve(tipping_address, alice_tokens);
    stop_cheat_caller_address(token_address);
    
    // Alice tries to tip unregistered user (should fail)
    let tip_amount = u256 { low: 100, high: 0 }; // 100 tokens
    start_cheat_caller_address(tipping_address, alice);
    tipping.tip_user(unregistered, tip_amount);
    stop_cheat_caller_address(tipping_address);
}

#[test]
fn test_reward_placeholder() {
    // Setup
    let (gossip_address, tipping_address, _) = setup();
    
    let gossip = iGossipDispatcher { contract_address: gossip_address };
    let tipping = ITippingDispatcher { contract_address: tipping_address };
    
    // Create and register user
    let alice: ContractAddress = 'alice'.try_into().unwrap();
    start_cheat_caller_address(gossip_address, alice);
    gossip.register_user('alice', 'ipfs://alice_profile');
    stop_cheat_caller_address(gossip_address);
    
    // Call reward placeholder (should not panic)
    let owner_address: ContractAddress = 'owner'.try_into().unwrap();
    start_cheat_caller_address(tipping_address, owner_address);
    let reward_amount = u256 { low: 50, high: 0 };
    tipping.reward_user_for_activity(alice, reward_amount, 'active_participation');
    stop_cheat_caller_address(tipping_address);
}

#[test]
#[should_panic(expected: 'Insufficient token allowance')]
fn test_tip_without_approval() {
    // Setup
    let (gossip_address, tipping_address, token_address) = setup();
    
    let gossip = iGossipDispatcher { contract_address: gossip_address };
    let tipping = ITippingDispatcher { contract_address: tipping_address };
    let mock_token = IMockERC20Dispatcher { contract_address: token_address };
    
    // Create users
    let alice: ContractAddress = 'alice'.try_into().unwrap();
    let bob: ContractAddress = 'bob'.try_into().unwrap();
    
    // Register Alice
    start_cheat_caller_address(gossip_address, alice);
    gossip.register_user('alice', 'ipfs://alice_profile');
    stop_cheat_caller_address(gossip_address);
    
    // Register Bob
    start_cheat_caller_address(gossip_address, bob);
    gossip.register_user('bob', 'ipfs://bob_profile');
    stop_cheat_caller_address(gossip_address);
    
    // Mint tokens to Alice
    let owner_address: ContractAddress = 'owner'.try_into().unwrap();
    start_cheat_caller_address(token_address, owner_address);
    let alice_tokens = u256 { low: 1000, high: 0 }; // 1,000 tokens
    mock_token.mint(alice, alice_tokens);
    stop_cheat_caller_address(token_address);
    
    // Alice tries to tip Bob without approval (should fail)
    let tip_amount = u256 { low: 100, high: 0 }; // 100 tokens
    start_cheat_caller_address(tipping_address, alice);
    tipping.tip_user(bob, tip_amount);
    stop_cheat_caller_address(tipping_address);
}

#[test]
#[should_panic(expected: 'Amount cannot be zero')]
fn test_tip_zero_amount() {
    // Setup
    let (gossip_address, tipping_address, token_address) = setup();
    
    let gossip = iGossipDispatcher { contract_address: gossip_address };
    let tipping = ITippingDispatcher { contract_address: tipping_address };
    let token = IERC20Dispatcher { contract_address: token_address };
    let mock_token = IMockERC20Dispatcher { contract_address: token_address };
    
    // Create users
    let alice: ContractAddress = 'alice'.try_into().unwrap();
    let bob: ContractAddress = 'bob'.try_into().unwrap();
    
    // Register Alice
    start_cheat_caller_address(gossip_address, alice);
    gossip.register_user('alice', 'ipfs://alice_profile');
    stop_cheat_caller_address(gossip_address);
    
    // Register Bob
    start_cheat_caller_address(gossip_address, bob);
    gossip.register_user('bob', 'ipfs://bob_profile');
    stop_cheat_caller_address(gossip_address);
    
    // Mint tokens to Alice
    let owner_address: ContractAddress = 'owner'.try_into().unwrap();
    start_cheat_caller_address(token_address, owner_address);
    let alice_tokens = u256 { low: 1000, high: 0 }; // 1,000 tokens
    mock_token.mint(alice, alice_tokens);
    stop_cheat_caller_address(token_address);
    
    // Alice approves Tipping contract to spend tokens
    start_cheat_caller_address(token_address, alice);
    token.approve(tipping_address, alice_tokens);
    stop_cheat_caller_address(token_address);
    
    // Alice tries to tip Bob with zero amount (should fail)
    let zero_amount = u256 { low: 0, high: 0 };
    start_cheat_caller_address(tipping_address, alice);
    tipping.tip_user(bob, zero_amount);
    stop_cheat_caller_address(tipping_address);
}

#[test]
fn test_multiple_tips() {
    // Setup
    let (gossip_address, tipping_address, token_address) = setup();
    
    let gossip = iGossipDispatcher { contract_address: gossip_address };
    let tipping = ITippingDispatcher { contract_address: tipping_address };
    let token = IERC20Dispatcher { contract_address: token_address };
    let mock_token = IMockERC20Dispatcher { contract_address: token_address };
    
    // Create users
    let alice: ContractAddress = 'alice'.try_into().unwrap();
    let bob: ContractAddress = 'bob'.try_into().unwrap();
    let charlie: ContractAddress = 'charlie'.try_into().unwrap();
    
    // Register users
    start_cheat_caller_address(gossip_address, alice);
    gossip.register_user('alice', 'ipfs://alice_profile');
    stop_cheat_caller_address(gossip_address);
    
    start_cheat_caller_address(gossip_address, bob);
    gossip.register_user('bob', 'ipfs://bob_profile');
    stop_cheat_caller_address(gossip_address);
    
    start_cheat_caller_address(gossip_address, charlie);
    gossip.register_user('charlie', 'ipfs://charlie_profile');
    stop_cheat_caller_address(gossip_address);
    
    // Mint tokens to Alice
    let owner_address: ContractAddress = 'owner'.try_into().unwrap();
    start_cheat_caller_address(token_address, owner_address);
    let alice_tokens = u256 { low: 1000, high: 0 }; // 1,000 tokens
    mock_token.mint(alice, alice_tokens);
    stop_cheat_caller_address(token_address);
    
    // Alice approves Tipping contract to spend tokens
    start_cheat_caller_address(token_address, alice);
    token.approve(tipping_address, alice_tokens);
    stop_cheat_caller_address(token_address);
    
    // Alice tips Bob
    let tip_amount1 = u256 { low: 100, high: 0 }; // 100 tokens
    start_cheat_caller_address(tipping_address, alice);
    tipping.tip_user(bob, tip_amount1);
    stop_cheat_caller_address(tipping_address);
    
    // Alice tips Charlie
    let tip_amount2 = u256 { low: 200, high: 0 }; // 200 tokens
    start_cheat_caller_address(tipping_address, alice);
    tipping.tip_user(charlie, tip_amount2);
    stop_cheat_caller_address(tipping_address);
    
    // Check balances
    let alice_balance = token.balance_of(alice);
    let bob_balance = token.balance_of(bob);
    let charlie_balance = token.balance_of(charlie);
    
    assert(alice_balance == alice_tokens - tip_amount1 - tip_amount2, 'Alice balance incorrect');
    assert(bob_balance == tip_amount1, 'Bob balance incorrect');
    assert(charlie_balance == tip_amount2, 'Charlie balance incorrect');
}

#[test]
fn test_set_token_contract() {
    // Setup
    let (gossip_address, tipping_address, token_address) = setup();
    let tipping = ITippingDispatcher { contract_address: tipping_address };
    
    // Get current token contract
    let current_token = tipping.get_token_contract();
    assert(current_token == token_address, 'Token wrong');
    
    // Set a new token contract
    let owner_address: ContractAddress = 'owner'.try_into().unwrap();
    let new_token_address: ContractAddress = 'new_token'.try_into().unwrap();
    
    start_cheat_caller_address(tipping_address, owner_address);
    tipping.set_token_contract(new_token_address);
    stop_cheat_caller_address(tipping_address);
    
    // Verify token contract was updated
    let updated_token = tipping.get_token_contract();
    assert(updated_token == new_token_address, 'Not updated');
} 