defmodule ElMeter do
  use GenStateMachine, callback_mode: :state_functions

  require Logger

  def start_link(_args) do
    GenStateMachine.start_link(__MODULE__, %{tokens: 0, total_consumption: 0}, name: __MODULE__)
  end

  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [arg]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  def resume() do
    GenStateMachine.call(__MODULE__, :start)
  end

  def suspend() do
    GenStateMachine.call(__MODULE__, :suspend)
  end

  def init(data) do
    GenStateMachine.cast(__MODULE__, :idle)
    {:ok, :running, data}
  end

  def get_state() do
    GenStateMachine.call(__MODULE__, :get_state)
  end

  ## Idle ##
  def idle({:call, from}, :start, %{}=state) do
    Logger.warn("ElMeter: Start measuring ...")
    ElProtocol.toggle_system(:on)
    consumption()
    GenStateMachine.cast(__MODULE__, :measure)
    {:next_state, :running, state, [{:reply, from, :ok}]}
  end

  def idle({:call, from}, :suspend, data) do
    no_consumption()
    #GenStateMachine.cast(__MODULE__, :no_consumption)
    {:next_state, :idle, data, [{:reply, from, :not_started}]}
  end

  def idle({:call, from}, :get_state, _data) do
    {:keep_state_and_data, [{:reply, from, :idle}]}
  end

  def idle({:call, from}, _, data) do
    no_consumption()
    #GenStateMachine.cast(__MODULE__, :no_consumption)
    {:next_state, :idle, data, [{:reply, from, :not_started}]}
  end

  def idle(:cast, :no_consumption, state) do
    no_consumption()
    #GenStateMachine.cast(__MODULE__, :no_consumption)
    {:next_state, :idle, state}
  end

  def idle(:cast, :measure, state) do
    Logger.info "idle cast measure"
    {:next_state, :idle, state}
  end

  def idle(_type, _state, data) do
    Logger.error "idle bad case 2 : #{inspect(_type)} | #{inspect(_state)}"
    {:next_state, :idle, data}
  end

  ## Running ##
  def running(:cast, :measure, %{}=state) do
    consumption()
    GenStateMachine.cast(__MODULE__, :measure)
    {:next_state, :running, state}
  end

  def running(:cast, :no_consumption, data) do
    consumption()
    GenStateMachine.cast(__MODULE__, :measure)
    {:next_state, :running, data}
  end

  def running(:cast, :idle, data) do
    #consumption()
    #GenStateMachine.cast(__MODULE__, :measure)
    {:next_state, :idle, data}
  end


  def running({:call, from}, :get_state, _data) do
    {:keep_state_and_data, [{:reply, from, {:state, :running}}]}
  end

  def running({:call, from}, :start, data) do
    consumption()
    GenStateMachine.cast(__MODULE__, :measure)
    {:next_state, :running, data, [{:reply, from, :already_started}]}
  end

  def running({:call, from}, :suspend, data) do
    ElProtocol.toggle_system(:off)
    no_consumption()
    Logger.warn("Electricity measuring stoped ...")
    {:next_state, :idle, data, [{:reply, from, :ok}]}
  end

  def running({:call, from}, _, data) do
    Logger.error "bad running case 1"
    {:next_state, :running, data, [{:reply, from, :not_suported}]}
  end

  def running(type, state, data) do
    Logger.error "running bad case 2 : #{inspect(type)} | #{inspect(state)}"
    {:next_state, :idle, data}
  end

  ## Internal
  @spec consumption() :: :ok | :error
  def consumption() do
    ElProtocol.get_consumption()
  end

  def no_consumption() do
    ElProtocol.no_consumption()
    :timer.sleep(10_000)
    GenStateMachine.cast(__MODULE__, :no_consumption)
  end

end
