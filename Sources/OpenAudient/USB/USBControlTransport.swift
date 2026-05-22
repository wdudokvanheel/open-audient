/// Low-level transport for UAC control transfers.
///
/// Abstracting the transport keeps the IOKit/IOUSBHost specifics out of the
/// control model and lets tests drive `AudientDevice` with an in-memory mock.
/// A C/IOUSBLib backend could be dropped in behind this protocol unchanged.
public protocol USBControlTransport: Sendable {
    /// Issue a GET_CUR for `request` and return the bytes read.
    func getCurrent(_ request: UACControlRequest) throws -> [UInt8]

    /// Issue a SET_CUR for `request` with `data` as the payload.
    func setCurrent(_ request: UACControlRequest, data: [UInt8]) throws

    /// Issue a block "memory" read (used by the meters): returns `length` bytes
    /// from `unitID` at `offset`.
    func getMemory(unitID: UInt8, offset: UInt16, length: UInt16) throws -> [UInt8]
}
