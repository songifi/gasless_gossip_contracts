use starknet::ContractAddress;
use crate::gossip::gossip::User;

#[starknet::interface]
pub trait iGossip<TContractState> {
    fn register_user(ref self: TContractState, username: felt252, profile_hash: felt252);
    fn update_profile(ref self: TContractState, new_profile_hash: felt252);
    fn get_user_by_address(self: @TContractState, address: ContractAddress) -> User;
    fn get_address_by_username(self: @TContractState, username: felt252) -> ContractAddress;
    fn is_username_taken(ref self: TContractState, username: felt252) -> bool;
    fn is_address_registered(ref self: TContractState, address: ContractAddress) -> bool;
    fn get_profile_hash(self: @TContractState, address: ContractAddress) -> felt252;
}

