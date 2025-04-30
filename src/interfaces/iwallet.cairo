use starknet::ContractAddress;

#[starknet::interface]
pub trait IWallet<TContractState> {
    fn deposit_token(ref self: TContractState, token_address: ContractAddress, amount: u256);
    fn withdraw_token(ref self: TContractState, token_address: ContractAddress, amount: u256, token1:ContractAddress, token2:ContractAddress, token3:ContractAddress);
    fn get_balance(self: @TContractState, user: ContractAddress, token_address: ContractAddress)-> u256;
    fn check_allowance_and_transfer(ref self: TContractState, token_addr: ContractAddress) -> u256;
}