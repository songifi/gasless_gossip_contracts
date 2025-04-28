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
use crate::message::MessageStore::Message;

#[starknet::interface]
pub trait iMessage<TContractState> {
    fn send_message(ref self: TContractState, to: ContractAddress, content_hash: felt252);
    fn get_messages_between(
        self: @TContractState, user1: ContractAddress, user2: ContractAddress,
    ) -> Array<Message>;
    fn get_message_count(
        self: @TContractState, user1: ContractAddress, user2: ContractAddress,
    ) -> u256;
    fn get_message_at_index(
        self: @TContractState, user1: ContractAddress, user2: ContractAddress, index: u256,
    ) -> Message;
    fn get_user_registry(self: @TContractState) -> ContractAddress;
}
