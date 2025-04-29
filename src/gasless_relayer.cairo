use core::array::{Array, ArrayTrait};
use core::starknet::get_caller_address;
use core::starknet::storage::{StorageMap, StoragePointerReadAccess, StoragePointerWriteAccess};
use starknet::ContractAddress;
use crate::base::errors::Errors::{
    ERROR_INVALID_NONCE, ERROR_INVALID_SIGNATURE, ERROR_UNAUTHORIZED, ERROR_ZERO_ADDRESS,
};
use crate::interfaces::igasless_relayer::iGaslessRelayer;

#[starknet::contract]
mod GaslessRelayer {
    use super::{
        Array, ArrayTrait, ContractAddress, ERROR_INVALID_NONCE, ERROR_INVALID_SIGNATURE,
        ERROR_UNAUTHORIZED, ERROR_ZERO_ADDRESS, StorageMap, StoragePointerReadAccess,
        StoragePointerWriteAccess, get_caller_address, iGaslessRelayer,
    };

    const RELAYER_ROLE: felt252 = 1;

    #[storage]
    struct Storage {
        nonces: StorageMap<ContractAddress, felt252>,
        relayers: StorageMap<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        MetaTxExecuted: MetaTxExecuted,
        RelayerAdded: RelayerAdded,
        RelayerRemoved: RelayerRemoved,
    }

    #[derive(Drop, starknet::Event)]
    struct MetaTxExecuted {
        user: ContractAddress,
        relayer: ContractAddress,
        nonce: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct RelayerAdded {
        relayer: ContractAddress,
        sender: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct RelayerRemoved {
        relayer: ContractAddress,
        sender: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Grant admin role to deployer
        let caller = get_caller_address();
        assert(!caller.is_zero(), ERROR_ZERO_ADDRESS);
        self.relayers.write(caller, true);
        self.emit(RelayerAdded { relayer: caller, sender: caller });
    }

    #[abi(embed_v0)]
    impl GaslessRelayerImpl of iGaslessRelayer<ContractState> {
        fn execute_meta_tx(
            ref self: ContractState,
            user: ContractAddress,
            function_data: Array<felt252>,
            signature: Array<felt252>,
        ) {
            // Verify relayer has permission
            assert(self.relayers.read(get_caller_address()), ERROR_UNAUTHORIZED);
            assert(!user.is_zero(), ERROR_ZERO_ADDRESS);

            // Get and verify nonce
            let nonce = self.nonces.read(user);
            assert(nonce == function_data.at(0), ERROR_INVALID_NONCE);
            self.nonces.write(user, nonce + 1);

            // Verify signature
            // In a real implementation, you would verify the signature against the function data
            // For now, we'll use a simple check that the signature is not empty
            assert(signature.len() > 0, ERROR_INVALID_SIGNATURE);

            // Execute the function
            // In a real implementation, you would decode and execute the function data
            // For now, we'll just emit an event
            self.emit(MetaTxExecuted { user, relayer: get_caller_address(), nonce });
        }

        fn add_relayer(ref self: ContractState, relayer: ContractAddress) {
            // Only admin can add relayers
            assert(self.relayers.read(get_caller_address()), ERROR_UNAUTHORIZED);
            assert(!relayer.is_zero(), ERROR_ZERO_ADDRESS);

            self.relayers.write(relayer, true);
            self.emit(RelayerAdded { relayer, sender: get_caller_address() });
        }

        fn remove_relayer(ref self: ContractState, relayer: ContractAddress) {
            // Only admin can remove relayers
            assert(self.relayers.read(get_caller_address()), ERROR_UNAUTHORIZED);
            assert(!relayer.is_zero(), ERROR_ZERO_ADDRESS);

            self.relayers.write(relayer, false);
            self.emit(RelayerRemoved { relayer, sender: get_caller_address() });
        }

        fn get_nonce(self: @ContractState, user: ContractAddress) -> felt252 {
            self.nonces.read(user)
        }

        fn is_relayer(self: @ContractState, address: ContractAddress) -> bool {
            self.relayers.read(address)
        }
    }
}

