import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

CHAR_C = ord('C')  # ASCII value 67
CHAR_F = ord('F')  # ASCII value 70
SEG_MAP = {
        0: 0x3F,  # 0b00111111 → segments a b c d e f
        1: 0x06,  # 0b00000110 → segments b c
        2: 0x5B,  # 0b01011011 → segments a b d e g
        3: 0x4F,  # 0b01001111 → segments a b c d g
        4: 0x66,  # 0b01100110 → segments b c f g
        5: 0x6D,  # 0b01101101 → segments a c d f g
        6: 0x7D,  # 0b01111101 → segments a c d e f g
        7: 0x07,  # 0b00000111 → segments a b c
        8: 0x7F,  # 0b01111111 → segments a b c d e f g
        9: 0x6F,  # 0b01101111 → segments a b c d f g

        CHAR_C: 0x39, # 0b00111001 → segments a d e f
        CHAR_F: 0x71, # 0b01110001 → segments a e f g
}


async def SPI(dut, data, bits=16, clk_delay=10):
    """SPI communication using SIO (uio_in[2]), CS (uio_out[0]), SCK (uio_out[1])"""

    # Resets MOSI, sets Chip Select (CS) = high, and sets Clock (SCK) = low
    dut.uio_in[2].value = 0
    dut.uio_out[0].value = 1 # CS HIGH (inactive)
    dut.uio_out[1].value = 0 # SCK LOW
    # Wait a bit, then bring CS low to start communication
    await Timer(clk_delay, units='us')
    dut.uio_out[0].value = 0 # CS LOW
    await Timer(clk_delay, units='us')

    # 1.Before clock rises (set data)
    # 2.While clock is high (data is sampled)
    # 3.After clock falls (before next bit)
    for i in reversed(range(bits)): # Iterate over bit positions from MSB to LSB
        bit  = (data >> i) & 1 # Right shift data by i positions and mask with 1 to extract the bit at position i
        dut.uio_in[2].value = bit # uio_in[2] represents the MOSI line in an SPI interface
        await Timer(clk_delay, units='us')
        dut.uio_out[1].value = 1 # SCK HIGH
        await Timer(clk_delay, units='us')
        dut.uio_out[1].value = 0 # SCK LOW
        await Timer(clk_delay, units='us')

    #  bring CS high to stop communication
    dut.uio_out[0].value = 1 # CS LOW
    dut.uio_out[2].value = 0 # Resets MOSI to 0
    await Timer(clk_delay * 5,units='us')


@cocotb.test()
async def temp_monitor(dut):
    """Test for the Digital Temprature Monitor"""
    # Start 10 kHz clock (100 us period)
    clock = Clock(dut.clk, 100_00, units="ps")
    cocotb.start_soon(clock.start()) # 10 KHz clock

    # Reset the Design
    dut.rst_n.value = 0
    await Timer(1, units="us")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Enable the Design
    dut.ena.value = 1
    # Set DIP switch inputs: ui_in
    # ui_in[0] = 0 (digit display),
    # ui_in[1] = 1 (LSB or MSB)
    # ui_in[2] = 0 (Celsius or Farehenite)
    dut.ui_in.value = 0b00000110

    # Temperature test cases: (raw SPI input, expected Celsius)
    test_cases = [
            (0x0000, 0),    # 0.0°C
            (0x00C8, 20),   # 20.0°C
            (0x0190, 40),   # 40.0°C # raw_data = 0x0190, expected_celsius = 40
            (0x01F4, 50),   # 50.0°C
            (0x02BC, 70),   # 70.0°C
            (0x03E8, 100),  # 100.0°C
            ]

    for raw_data, expected_C in test_cases:
        # raw_data is the 16-bit SPI input to the DUT (sent as a digital sensor reading)
        # expected_celsius is the real temperature (in °C) that this raw data represents
        for use_F in [0, 1]: # 0 = display temperature in °C, 1 = display temperature in °F

            # send data
            dut.ui_in.value = use_F << 2
            await SPI(dut, raw_data)
            await Timer(500, units='us')

            # Compute target values
            temp = int(round(expected_C * 9/5 + 32)) if use_F else expected_C
            msb = temp // 10
            lsb = temp % 10

            # check MSB digit
            dut.ui_in.value = (1 << 1) | (use_F << 2) # ui_in[1]=1, [2] = C/F
            await Timer(200, units='us')
            seg = dut.uo_out.value.integer
            assert seg == SEG_MAP[msb], f"MSB mismatch: {temp} -> got 0x{seg:X}, expected 0x{SEG_MAP[msb]:X}"

            # check LSB digit
            dut.ui_in.value = (0 << 1) | (use_F << 2) # ui_in[1]=1, [2] = C/F
            await Timer(200, units='us')
            seg = dut.uo_out.value.integer
            assert seg == SEG_MAP[lsb], f"LSB mismatch: {temp} -> got 0x{seg:X}, expected 0x{SEG_MAP[lsb]:X}"

            # check C/F character
            dut.ui_in.value = (1 << 0) | (use_F << 2)  # ui_in[0]=1, [2] = C/F
            await Timer(200, units='us')
            seg = dut.uo_out.value.integer
            expected_char = CHAR_F if use_F else CHAR_C
            assert seg == SEG_MAP[expected_char], f"C/F mismatch: {temp} -> got 0x{seg:X}, expected 0x{SEG_MAP[expected_char]:X}"


            cocotb.log.info(f"PASS: raw=0x{raw_data:04X}, Temp={temp}°{'F' if use_fahrenheit else 'C'} -> digits {msb}{lsb}")
