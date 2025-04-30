use contract::interfaces::igasless_relayer::{
    iGaslessRelayerDispatcher, iGaslessRelayerDispatcherTrait,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address};
use starknet::ContractAddress;

fn setup() -> ContractAddress {
    let contract = declare("GaslessRelayer").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}

#[test]
fn test_execute_meta_tx() {
    let contract_address = setup();
    let contract = iGaslessRelayerDispatcher { contract_address };

    // Setup test data
    let user_address: ContractAddress = 'user'.try_into().unwrap();
    let function_data = array![0]; // Nonce 0
    let signature = array![1]; // Dummy signature

    // Execute meta transaction
    contract.execute_meta_tx(user_address, function_data, signature);

    // Verify nonce was incremented
    let nonce = contract.get_nonce(user_address);
    assert(nonce == 1, 'Nonce should be 1');
}

#[test]
#[should_panic(expected: 'Caller is not a relayer')]
fn test_execute_meta_tx_unauthorized() {
    let contract_address = setup();
    let contract = iGaslessRelayerDispatcher { contract_address };

    // Setup test data
    let user_address: ContractAddress = 'user'.try_into().unwrap();
    let function_data = array![0];
    let signature = array![1];

    // Try to execute meta transaction without being a relayer
    contract.execute_meta_tx(user_address, function_data, signature);
}

#[test]
fn test_add_relayer() {
    let contract_address = setup();
    let contract = iGaslessRelayerDispatcher { contract_address };

    // Add new relayer
    let new_relayer: ContractAddress = 'relayer'.try_into().unwrap();
    contract.add_relayer(new_relayer);

    // Verify relayer was added
    let is_relayer = contract.is_relayer(new_relayer);
    assert(is_relayer, 'Should be a relayer');
}

#[test]
#[should_panic(expected: 'Caller is not a relayer')]
fn test_add_relayer_unauthorized() {
    let contract_address = setup();
    let contract = iGaslessRelayerDispatcher { contract_address };

    // Try to add relayer without being admin
    let new_relayer: ContractAddress = 'relayer'.try_into().unwrap();
    start_cheat_caller_address(contract_address, new_relayer);
    contract.add_relayer(new_relayer);
}

#[test]
fn test_remove_relayer() {
    let contract_address = setup();
    let contract = iGaslessRelayerDispatcher { contract_address };

    // Add and then remove relayer
    let relayer: ContractAddress = 'relayer'.try_into().unwrap();
    contract.add_relayer(relayer);
    contract.remove_relayer(relayer);

    // Verify relayer was removed
    let is_relayer = contract.is_relayer(relayer);
    assert(!is_relayer, 'Should not be a relayer');
}

#[test]
#[should_panic(expected: 'Caller is not a relayer')]
fn test_remove_relayer_unauthorized() {
    let contract_address = setup();
    let contract = iGaslessRelayerDispatcher { contract_address };

    // Add relayer
    let relayer: ContractAddress = 'relayer'.try_into().unwrap();
    contract.add_relayer(relayer);

    // Try to remove relayer without being admin
    start_cheat_caller_address(contract_address, relayer);
    contract.remove_relayer(relayer);
}

#[test]
#[should_panic(expected: 'Invalid signature')]
fn test_execute_meta_tx_invalid_signature() {
    let contract_address = setup();
    let contract = iGaslessRelayerDispatcher { contract_address };

    // Setup test data with empty signature
    let user_address: ContractAddress = 'user'.try_into().unwrap();
    let function_data = array![0];
    let signature = array![];

    // Try to execute meta transaction with invalid signature
    contract.execute_meta_tx(user_address, function_data, signature);
}

#[test]
#[should_panic(expected: 'Invalid nonce')]
fn test_execute_meta_tx_invalid_nonce() {
    let contract_address = setup();
    let contract = iGaslessRelayerDispatcher { contract_address };

    // Setup test data with wrong nonce
    let user_address: ContractAddress = 'user'.try_into().unwrap();
    let function_data = array![1]; // Nonce 1 when it should be 0
    let signature = array![1];

    // Try to execute meta transaction with invalid nonce
    contract.execute_meta_tx(user_address, function_data, signature);
}

#[test]
fn test_multiple_meta_transactions() {
    let contract_address = setup();
    let contract = iGaslessRelayerDispatcher { contract_address };

    // Setup test data
    let user_address: ContractAddress = 'user'.try_into().unwrap();
    let signature = array![1];

    // Execute multiple meta transactions
    let mut i: u32 = 0;
    loop {
        if i >= 3 {
            break;
        }
        let function_data = array![i.into()];
        contract.execute_meta_tx(user_address, function_data, signature);
        i += 1;
    }

    // Verify final nonce
    let nonce = contract.get_nonce(user_address);
    assert(nonce == 3, 'Nonce should be 3');
}

#[test]
fn test_multiple_relayers() {
    let contract_address = setup();
    let contract = iGaslessRelayerDispatcher { contract_address };

    // Add multiple relayers
    let relayers = array![
        'relayer1'.try_into().unwrap(),
        'relayer2'.try_into().unwrap(),
        'relayer3'.try_into().unwrap(),
    ];

    for relayer in relayers {
        contract.add_relayer(relayer);
        let is_relayer = contract.is_relayer(relayer);
        assert(is_relayer, 'Should be a relayer');
    }
}

#[test]
#[should_panic(expected: 'Zero address not allowed')]
fn test_add_zero_address_relayer() {
    let contract_address = setup();
    let contract = iGaslessRelayerDispatcher { contract_address };

    // Try to add zero address as relayer
    let zero_address: ContractAddress = 0.try_into().unwrap();
    contract.add_relayer(zero_address);
}

#[test]
fn test_remove_and_add_relayer() {
    let contract_address = setup();
    let contract = iGaslessRelayerDispatcher { contract_address };

    // Add relayer
    let relayer: ContractAddress = 'relayer'.try_into().unwrap();
    contract.add_relayer(relayer);

    // Remove relayer
    contract.remove_relayer(relayer);
    let is_relayer = contract.is_relayer(relayer);
    assert(!is_relayer, 'Should not be a relayer');

    // Add relayer again
    contract.add_relayer(relayer);
    let is_relayer = contract.is_relayer(relayer);
    assert(is_relayer, 'Should be a relayer again');
}

#[test]
fn test_initial_admin_is_relayer() {
    let contract_address = setup();
    let contract = iGaslessRelayerDispatcher { contract_address };

    // Verify deployer is a relayer
    let is_relayer = contract.is_relayer(contract_address);
    assert(is_relayer, 'Deployer should be a relayer');
}
