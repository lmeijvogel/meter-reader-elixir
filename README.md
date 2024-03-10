# MeterReader

## Services

The current meter-reader service uses a few services to store data:

### InfluxDB

This is my main storage: The web app will query this. Currently every measurement is stored (every second D:).

### MySQL / MariaDB

I use this as a backup store: Every 15m, the current p1 measurement, augmented with the number of water "ticks" is stored.

### Redis

The Redis instance on the meter-reader host only stores data in-memory.

It is used to store:
* `water_meter_last_ticks`: The last two ticks, to determine the current water usage.
* `water_count` -- This is the cumulative number of ticks: This is added to each MySQL measurement

Some other fields are filled but seem to not be used:

* `water_meter_water_count` -- This is the default name that stores the cumulative number of "ticks".

Both of these can be replaced by Elixir agents.

## Mysql

Currently trying plain SQL via MyXQL: https://github.com/elixir-ecto/myxql

## InfluxDB

Nothing yet, will try https://github.com/mneudert/instream

## Example P1 report
```
/ABCDEFGHI-METER

1-3:0.2.8(50)
0-0:1.0.0(240224163846W)
0-0:96.1.1(4530303539303030303030353936363139)
1-0:1.8.1(003900.313*kWh)
1-0:1.8.2(004184.285*kWh)
1-0:2.8.1(000934.490*kWh)
1-0:2.8.2(002115.131*kWh)
0-0:96.14.0(0001)
1-0:1.7.0(00.000*kW)
1-0:2.7.0(00.168*kW)
0-0:96.7.21(00005)
0-0:96.7.9(00002)
1-0:99.97.0(2)(0-0:96.7.19)(220808111826S)(0000000407*s)(210516114015S)(0000003077*s)
1-0:32.32.0(00014)
1-0:32.36.0(00000)
0-0:96.13.0()
1-0:32.7.0(235.7*V)
1-0:31.7.0(002*A)
1-0:21.7.0(00.000*kW)
1-0:22.7.0(00.168*kW)
0-1:24.1.0(003)
0-1:96.1.0(4730303634303032303037303331343230)
0-1:24.2.1(240224163506W)(03991.882*m3)
!E62D
```
Newlines are CRLF

Connection:
P1_CONVERTER_DEVICE="/dev/p1_converter"
P1_CONVERTER_BAUD_RATE="115200"
P1_CONVERTER_MESSAGE_START="/ABCDEFGHI-METER"
serial_port.data_bits = 7
serial_port.stop_bits = 1
serial_port.parity = SerialPort::EVEN

## Simulate serial port

Create a pair of serial ports like this:
```
$ socat -d -d pty,rawer,echo=0 pty,rawer,echo=0
```

This will create two ports, e.g. /dev/pts/5 and /dev/pts/6

We can use minicom to communicate through these:

```
$ minicom -b 115200 -D /dev/pts/5
```
Configuration of data, stop bits, parity is done through the minicom UI. 

Another way to write data to the serial port is to just cat data there:

```
$ cat example.p1 > /dev/pts/5
```

But I don't know whether that will correctly be picked up by software that's configured with some combination of data,stop and parity bits.

## Read serial port

Use the Circuits.UART package.

To open a connection:

```
{ :ok, pid } = Circuits.UART.start_link
Circuits.UART.open(pid, "/dev/pts/5", speed: 115200, data_bits: 7, stop_bits: 1, parity: :even, active: false)

Circuits.UART.read(pid, timeout_in_ms)
```

`active: false` means that we have to actively ask for messages by doing a read(). `active: true` is probably what we want: Circuits will 
send a message when data is received. I do not know where those messages are sent and how to receive them.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `meter_reader` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:meter_reader, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/meter_reader>.

