defmodule RabbitMQ do
  use GenServer

  ## Client API

  def start_link(_ag) do
	GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end


  @doc """
  Subscribe to rabbitmq queue
  The 'callback' is a pid who will handle received messages
  """

  def send_msg(server, {message}) do
	GenServer.call(server, {:send,message})
  end

  def send_msg(message) do
	GenServer.call(__MODULE__, {:send,message})
  end

  ## Server Callbacks

  def init(:ok) do
	{:ok, setup()}
  end

  def handle_call({:send, message},_from, state) do
	send_int(state[:connection], {message, state[:exchange],state[:routing_key]})
	{:reply, :ok, state}
  end


  def handle_cast(any, state) do
	IO.inspect any
	{:noreply, state}
  end


  def handle_info({:DOWN,pid_ref, :process, _process,
				   {:shutdown,{:server_initiated_close, _error_code,reason}}},
		%{:conn_ref => conn_ref}=_state) when pid_ref == conn_ref do
	IO.inspect reason
	{:noreply, setup()}
  end

  def handle_info({:basic_deliver, _payload, _amqp_map}, state) do
	{:noreply, state}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _tag}}, state) do
	{:noreply, state}
  end

  def handle_info(any, state) do
	IO.inspect any
	{:noreply, state}
  end

  ###### INTERNAL FUNCTIONS ######
  defp setup do
	rabbit_settings   = Application.get_env :wt, :rabbitmq_settings
	{:ok, connection} = AMQP.Connection.open(rabbit_settings)
	conn_ref = :erlang.monitor(:process,Map.get(connection, :pid))

	chan_ref =
	  case Application.get_env(:wt, :amqp_queue_subscribe?) do
		:true ->
		  {:ok, channel} = AMQP.Channel.open(connection)
		  :erlang.monitor(:process,Map.get(channel,:pid))
		  AMQP.Basic.consume(channel,
			Application.get_env(:wt, :amqp_queue),
			nil,
			no_ack: true)
		:false  ->
		  nil
	  end

	%{:connection  => connection,
	  :conn_ref    => conn_ref,
	  :chan_ref    => chan_ref,
	  :exchange    => Application.get_env(:wt, :amqp_exchange),
	  :routing_key => Application.get_env(:wt, :amqp_routing_key)}

  end

  defp send_int(connection, {message, exchange, routing_key}) do
	{:ok, channel} = AMQP.Channel.open(connection)
	AMQP.Basic.publish(channel, exchange, routing_key, message)
	AMQP.Channel.close(channel)
  end
end
