defmodule ElManager do
  use GenServer
  require Logger

  ## TODO: Consider FSM instead of GenServer

  alias Aecore.Keys.Worker, as: Keys

  @min_limit 4000
  @peer "31.13.251.15:4000"
  @watt_price 1000
  @to_node_c <<4,255,228,44,214,22,200,123,104,34,84,111,12,53,180,102,215,223,219,159,12,
    129,150,104,97,56,250,96,242,240,200,254,160,205,95,47,224,218,44,24,216,4,
    244,115,72,242,178,62,74,164,92,129,228,115,186,154,222,100,125,233,154,70,
    251,131,64>>

  def start_link(_arg) do
    GenServer.start_link(__MODULE__,[] ,name: __MODULE__)
  end

  def resume() do
    ElMeter.resume()
  end

  def stop() do
    ElMeter.suspend()
  end

  def current_tokens() do
    ElMeter.current_tokens()
  end

  def get_state() do
    ElMeter.get_state()
  end

  def init(_) do
    schedule_work(2000)
    {:ok, 0}
  end

  def handle_info(:work, state) do
    last_minute_consump = get_consumption()
    acc_balance = check_balance()
    #Kernel.round(last_minute_consump * @watt_price)
    amount = Kernel.round(last_minute_consump * @watt_price) #Float.round( (last_minute_consump * @watt_price), 2)
    pay(acc_balance, amount)
    schedule_work(60_000)
    Logger.info("Minutes : #{inspect(state)} | Tokens to pay : #{amount} | Current balance : #{inspect(acc_balance)} | Threshold : #{treshold()}")
    {:noreply, state + 1}
  end

  def treshold() do
    @min_limit
  end

  def check_balance_erp() do
    Aehttpclient.Client.get_account_balance({@peer, Base.encode16(@to_node_c)})
  end

  def check_balance() do
    {:ok, pk} = Aecore.Keys.Worker.pubkey
    case Aehttpclient.Client.get_account_balance({@peer, Base.encode16(pk)}) do
      {:ok, %{"balance" => balance}} -> balance
      _ -> 0
    end
  end

  defp pay(balance, 0) when balance >= @min_limit do
    ElMeter.resume()
    Logger.info("Nothing to pay for, but enought balance, resume")
  end
  defp pay(_, 0) do
    ElMeter.suspend
    Logger.info("Nothing to pay for and not enought balance, suspend")
  end
  defp pay(balance, tokens_to_pay) when balance >= @min_limit + tokens_to_pay do
    Logger.info("Enought balance  [#{inspect(balance)}] do payment")
    make_tx(tokens_to_pay)
    ElMeter.resume()
  end
  # defp pay(balance, tokens) when balance > tokens do
  #   Logger.info("Enought balance [#{inspect(balance)}] for one payment, then we go to suspend ")
  #   make_tx(tokens)
  #   ElMeter.suspend()
  # end
  # Defp
  defp pay(balance, tokens) do
    Logger.info("Not enought balance [#{inspect(balance)}]")
    make_tx(tokens)
    ElMeter.suspend()
    tokens
  end

  def make_tx(tokens) do
    nonce =
      case :erlang.get(:nonce) do
        :undefined ->
          :erlang.put(:nonce, 2)
          2
        nonce ->
          :erlang.put(:nonce, nonce + 1)
          nonce + 1
      end
    {:ok, tx} =
      Keys.sign_tx(@to_node_c, tokens, nonce, 1)
    tx = Aecore.Utils.Serialization.tx(tx, :serialize)
    Aecore.Peers.Worker.send_to_peer(:new_tx, tx, @peer)

  end

  defp schedule_work(t) do
    Process.send_after(self(), :work, t)
  end

  defp get_consumption() do
    b = :os.system_time(:micro_seconds)
    min = 1000000 * 60
    e = b - min
    {:ok, res} = ElasticSearch.request({"dev","embedded_green",b,e, :minute})
    [{:ok,last}|_]=res

    last = JSON.decode! last
    [last] = last["root"]

    l1 = last["l1"]["kw"]
    l2 = last["l2"]["kw"]
    l3 = last["l3"]["kw"]
    case l1 != nil and l2 != nil and l3 != nil do
      true -> (( l1 + l2 + l3 ) / 3 ) / 60
      false -> 0
    end

  end

end
