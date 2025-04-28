use starknet::ContractAddress;

#[starknet::interface]
pub trait ITipping<TContractState> {
    fn tip_user(ref self: TContractState, to: ContractAddress, amount: u256);
    fn reward_user_for_activity(ref self: TContractState, to: ContractAddress, amount: u256, activity_type: felt252);
    fn set_token_contract(ref self: TContractState, token_contract: ContractAddress);
    fn get_token_contract(self: @TContractState) -> ContractAddress;
} 