// Nen Shared Error Types
// For use in both embedded and distributed NenDB

pub const Error = error{
    NodeBufferFull,
    EdgeBufferFull,
    ArenaFull,
    BatchFull,
    CsvParseError,
    JsonSerializeError,
    // ...add more as needed
};
