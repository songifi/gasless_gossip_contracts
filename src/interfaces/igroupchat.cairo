
use starknet::ContractAddress;

#[starknet::interface]
trait IGroupChat<TContractState> {
    // Admin functions
    fn create_group(ref self: TContractState, metadata_uri: felt252) -> felt252;
    fn add_member(ref self: TContractState, group_id: felt252, member: ContractAddress);
    fn remove_member(ref self: TContractState, group_id: felt252, member: ContractAddress);
    fn change_admin(ref self: TContractState, group_id: felt252, new_admin: ContractAddress);
    
    // View functions
    fn get_group_metadata(self: @TContractState, group_id: felt252) -> felt252;
    fn get_group_admin(self: @TContractState, group_id: felt252) -> ContractAddress;
    fn is_group_member(self: @TContractState, group_id: felt252, address: ContractAddress) -> bool;
    fn get_members_count(self: @TContractState, group_id: felt252) -> u32;
    fn is_user_in_group(self: @TContractState, user: ContractAddress, group_id: felt252) -> bool;
} 
