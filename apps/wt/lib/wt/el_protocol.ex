defmodule ElProtocol do
  use GenServer

  alias TestProtocol, as: Protocol
  alias ElixirALE.GPIO

  @time Application.get_env(:wt, :timer)

  def start_link(_arg) do
    GenServer.start_link(__MODULE__,[] ,name: __MODULE__)
  end

  def get_consumption() do
    GenServer.call(__MODULE__, :get_consumption, 15000)
  end

  def no_consumption() do
    GenServer.call(__MODULE__, :no_consumption, 15000)
  end

  def toggle_system(action) do
    GenServer.call(__MODULE__, {:toggle, action})
  end

  def init(_) do
    {:ok, setup()}
  end

  def setup() do
    {:ok, pid} = Nerves.UART.start_link
    Nerves.UART.open(pid, Application.get_env(:wt,:port),
      speed: Application.get_env(:wt,:speed),active: false)
    #schedule_work(50)
    alias ElixirALE.GPIO
    {:ok, gpio} = GPIO.start_link(20, :output)
    %{serial: pid, gpio: gpio, start_timestamp: :os.system_time(:seconds)}
  end


  defp schedule_work(t) do
    Process.send_after(self(), :work, t)
  end

  def handle_call(:get_consumption, _from, %{serial:  pid}=state) do
    {time, map} = :timer.tc(Protocol, :process, [pid])
    {:ok, json}=JSON.encode(map)
    RabbitMQ.send_msg json
    {:reply, :ok, state}
  end

  def handle_call(:no_consumption, _from, %{serial:  pid}=state) do
    l   =
      %{amperes: 0,
        volts: 0, cos: 0,
        kw: 0, kv: 0}
    map =
      %{root: [%{"name"       => "Димят Варна",
                 "timestamp"  => :os.system_time(:micro_seconds),
                 "+A"         => 0,
                 "+Ri"        => 0,
                 "kw_total"   => 0,
                 "kv_total"   => 0,
                 "tokens"     => ElManager.check_balance(),
                 "threshold"  => ElManager.treshold(),
                 l1: l,
                 l2: l,
                 l3: l}]}
    {:ok, json}=JSON.encode(map)
    RabbitMQ.send_msg json
    {:reply, :ok, state}
  end

  def handle_call({:toggle, :on}, _from, %{gpio: pid}=state) do
    GPIO.write(pid, 1)
    {:reply, :system_started, state}
  end
  def handle_call({:toggle, :off}, _from, %{gpio: pid}=state) do
    GPIO.write(pid, 0)
    {:reply, :system_stopped, state}
  end

  def handle_info(:work,%{serial: pid, start_timestamp: start_timestamp}=state) do
    {time, map} = :timer.tc(Protocol, :process, [pid])
    IO.inspect "[ estimate time total : #{time/1000000} ]"

    {:ok,json}=JSON.encode(map)
    RabbitMQ.send_msg json
    #IO.inspect json
    #IO.inspect " ========== "

    #schedule_work(0)
    {:noreply, state}
  end

  def process(pid) do
    {time, {l1,l2,l3}} = :timer.tc(Protocol, :get_phases, [pid])
    {time, kv_total}   = :timer.tc(Protocol, :get_acc_total, [pid, 3])
    {time, kw_total}   = :timer.tc(Protocol, :get_acc_total, [pid, 1])

    #IO.inspect "estimate time for phases   : #{time}"
    #IO.inspect "estimate time for kv_total : #{time}"
    #IO.inspect "estimate time for wv_total : #{time}"

    %{root: [%{"name"      => "Цех1",
               "timestamp" => :os.system_time(:micro_seconds),
               "+A"        => kw_total/3,
               "+Ri"       => kv_total/3,
               "kw_total"  => ((l1.kw + l2.kw + l3.kw) / 3),
               "kv_total"  => ((l1.kv + l2.kv + l3.kv) / 3),
               "tokens"    => ElManager.check_balance(),
               "threshold"  => ElManager.treshold(),
               l1: l1,
               l2: l2,
               l3: l3}]}
  end

  def get_phases(pid) do
    all_phases =
    for phase_num <- 1..3 do
      Nerves.UART.write(pid, "#R0P#{phase_num};")
      :timer.sleep(@time)
      case Nerves.UART.read(pid) do
        {:ok,res0} ->

          if res0 !="" do
            [_,voltage,current,frequency,active_p,reactive_p,apparent_p]=
              String.split res0,","
            voltage    = String.to_integer(voltage)/10
            current    = String.to_integer(current)/10000
            active_p   = String.to_integer(active_p)/100
            reactive_p = String.to_integer(reactive_p)/100
            apparent_p =
              String.replace(apparent_p,"\r","")
              |> String.to_integer()
              |> :erlang./(100)
            #IO.inspect("res apperent_p : #{inspect(apparent_p)}")
            phase   = String.to_atom("l#{phase_num}")

            cos =
              case current != 0 or voltage != 0 do
                true ->
                  apparent_p/(current*voltage)
                false -> 0
              end

            %{phase => %{amperes: current ,
                         volts: voltage, cos: cos,
                         kw: apparent_p, kv: reactive_p}}

          else
            :error
          end
        {:error,reason}-> reason
      end
    end
    {(Enum.at all_phases,0).l1,(Enum.at all_phases,1).l2,(Enum.at all_phases,2).l3}
  end

  def get_acc_total(pid, type) do
    total =
    for n <- 1..3 do
      Nerves.UART.write(pid, "#R0N#{n}#{type};")
      :timer.sleep(@time)
      case Nerves.UART.read(pid) do
        {:ok, res} ->
          #IO.inspect("res total : #{inspect(res)}")
          [_h,t] = String.split(res, ",")
          str=String.replace(t, "\r", "")
          String.to_integer(str) / 1000
        {:ok, any} ->
          IO.inspect("[get acc total] any : #{inspect(any)}")
          :reactive_error
      end
    end
    Enum.sum(total)
  end
end
