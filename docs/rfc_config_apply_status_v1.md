# RFC: CONFIG_APPLY Readback Status v1

Date: 2026-06-28

## Summary

Keep the existing `0x006F CONFIG_APPLY` address. Writes remain the apply trigger. Reads return a status word so ARM can verify that a shadow-register commit was observed by FPGA logic.

## Register

`0x006F CONFIG_APPLY`

Write:

- bit 0: request an apply pulse.

Read:

- bit 0: `apply_busy`, asserted while the active snapshot update is being reported.
- bits 15:8: `apply_seq`, increments after each observed apply event.
- other bits: reserved, read as zero.

ARM software reads `apply_seq`, writes bit 0, then polls until `apply_seq` changes and `apply_busy` is zero. A timeout reports an apply failure instead of acknowledging an unverified commit.
