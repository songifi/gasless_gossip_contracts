pub mod Errors {
    pub const ERROR_USERNAME_TAKEN: felt252 = 'Username is already taken';
    pub const ERROR_ADDRESS_REGISTERED: felt252 = 'Address already registered';
    pub const ERROR_USERNAME_LENGTH: felt252 = 'Username length invalid';
    pub const ERROR_NOT_REGISTERED: felt252 = 'User not registered';
    pub const ERROR_UNAUTHORIZED: felt252 = 'Only owner can update profile';
    pub const ERROR_ZERO_ADDRESS: felt252 = 'Zero address not allowed';
    pub const ERROR_USERNAME_NOT_FOUND: felt252 = 'Username not found';


    pub const ERROR_SELF_MESSAGE: felt252 = 'Cannot message self';

    pub const ERROR_INVALID_RECEIVER: felt252 = 'Invalid receiver';
    pub const ERROR_EMPTY_CONTENT: felt252 = 'Empty content hash';
}
