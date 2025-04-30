use core::array::Array;
use starknet::ContractAddress;

#[starknet::interface]
pub trait iGaslessRelayer<TContractState> {
    fn execute_meta_tx(
        ref self: TContractState,
        user: ContractAddress,
        function_data: Array<felt252>,
        signature: Array<felt252>,
    );
    fn add_relayer(ref self: TContractState, relayer: ContractAddress);
    fn remove_relayer(ref self: TContractState, relayer: ContractAddress);
    fn get_nonce(self: @TContractState, user: ContractAddress) -> felt252;
    fn is_relayer(self: @TContractState, address: ContractAddress) -> bool;
}
