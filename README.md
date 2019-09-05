# keymem
Key memory module for the NTS engine.


## Status
Functionally completed. Not debugged. Not ready for use.


## Introduction
The NTS engine should support multiple server keys. The keys are used
to:
1. Decrypt received cookies and verify NTS packet authenticity.
2. Encrypt generated cookies and generate NTS packet MAC tag.

For received NTS packets the server key used is identified using a key
ID. Fpr NTS packets to be sent the current server key (out of the set of
valid keys) are used.

The keymem also needs to support counters that tracks which keys are
being used. And possibly more importantly, how often an invalid key is
being requested when processing an incoming NTS packet.


## Implementation details
The keymem currently supports four 512-bit keys. Each key has an
associated 32-bit ID as well as metadata for actual key length and if
the key is valid or not.

The host can set which of the keys is the current server key as well as
setting or clearing the valid bits as an atomic operation.

The statistics counters are non saturating. The counters support write
to clear to allow the host to reset the counters at will.


### Host interface
The host interface mimics a synchronous memory with 8-bit address and
32-bit data.

```
  ADDR_NAME0          = 0x00;
  ADDR_NAME1          = 0x01;
  ADDR_VERSION        = 0x02;

  ADDR_CTRL           = 0x08;
  CTRL_KEY0_VALID_BIT = 0;
  CTRL_KEY1_VALID_BIT = 1;
  CTRL_KEY2_VALID_BIT = 2;
  CTRL_KEY3_VALID_BIT = 3;
  CTRL_CURR_LOW_BIT   = 16;
  CTRL_CURR_HIGH_BIT  = 17;

  ADDR_KEY0_ID        = 0x10;
  ADDR_KEY0_LENGTH    = 0x11;

  ADDR_KEY1_ID        = 0x12;
  ADDR_KEY1_LENGTH    = 0x13;

  ADDR_KEY2_ID        = 0x14;
  ADDR_KEY2_LENGTH    = 0x15;

  ADDR_KEY3_ID        = 0x16;
  ADDR_KEY3_LENGTH    = 0x17;

  ADDR_KEY0_COUNTER   = 0x30;
  ADDR_KEY1_COUNTER   = 0x31;
  ADDR_KEY2_COUNTER   = 0x32;
  ADDR_KEY3_COUNTER   = 0x33;
  ADDR_ERROR_COUNTER  = 0x34;

  ADDR_KEY0_START     = 0x40;
  ADDR_KEY0_END       = 0x4f;

  ADDR_KEY1_START     = 0x50;
  ADDR_KEY1_END       = 0x5f;

  ADDR_KEY2_START     = 0x60;
  ADDR_KEY2_END       = 0x6f;

  ADDR_KEY3_START     = 0x70;
  ADDR_KEY3_END       = 0x7f;

```

### Client interface
The client interface supports commands to receive the current key as
well as key with a given ID.


## Implementation results
Results from implementation in the target FPGA.

To Be Added.
