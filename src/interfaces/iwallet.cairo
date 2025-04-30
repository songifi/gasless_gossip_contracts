use starknet::ContractAddress;

#[starknet::interface]
pub trait IWallet<T> {
    fn deposit_token(ref self: T, token_address: ContractAddress, amount: u256);
    fn withdraw_token(ref self: T, token_address: ContractAddress, amount: u256);
    fn get_balance(self: @T, user: ContractAddress, token_address: ContractAddress) -> u256;
}