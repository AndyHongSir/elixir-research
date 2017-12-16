defmodule ElasticSearch do
  use GenServer
  ####Client API####
  def start_link(_args) do
    #GenServer.start_link(__MODULE__, %{})
    GenServer.start_link(__MODULE__,[] ,name: __MODULE__)
  end

  def request(params) do
	GenServer.call(__MODULE__,{:request,params}, :infinity)
  end

  def write_info(server, params) do
	GenServer.call(server,{:put_records,params})
  end

  def create_index(server,index) do
	GenServer.call(server,{:create_index,index})
  end

  def create_type(server,params) do
	GenServer.call(server,{:create_type,params})
  end

  def delete_index(server,index) do
	GenServer.call(server,{:delete_index,index})
  end

  def delete_type_data(server,params) do
	GenServer.call(server,{:delete_type,params})
  end

  ###Server Callbacks###
  def init(state) do
	{:ok, state}
  end

  def handle_call({:create_index,index},_from,state) do
	Elastex.Index.create(index)|> Elastex.run
	{:reply,:created,state}
  end

  def handle_call({:create_type,{index,type}},_from,state) do
	Elastex.Document.index(%{},index,type)|> Elastex.run
	{:reply,:created,state}
  end

  def handle_call({:delete_index,index},_from,state) do
	Elastex.Index.delete(index)|> Elastex.run
	{:reply,:deleted,state}
  end

  def handle_call({:delete_type_data,{index,type}},_from,state) do
	Elastex.Document.delete(index,type,"")|> Elastex.run
	{:reply,:deleted,state}
  end

  ## ========================================================================================================
  ##   -- periods --
  ##      29.07 12:00 => 1501318800000000
  ##      28.07 21:00 => 1501264800000000
  ##
  ##      29.07 22:00 => 1501354800000000
  ##      28.07 22:00 => 1501268400000000
  ##
  ##      testing
  ##      28.07 20:01 => 1501261260000000
  ##      28.07 20:00 => 1501261200000000
  ##
  ##    -- execute --
  ##      {:ok,server}=ElasticSearch.start_link
  ##      ElasticSearch.request(server,{"krz","pod14",1501318800000000,1501264800000000, :hours})
  ## ========================================================================================================
  def handle_call({:request,{index,type,ts_from,ts_to,period}},_from,state) do
    multi_query = QueryBuilder.multi_query(index,type,ts_from,ts_to,period)
    {:ok,elastic_response} =
      Elastex.Search.multi_search(multi_query)|>
      Elastex.Search.params([size: 0, timeout: :infinity, recv_timeout: :infinity, index: index, type: type])|>
      Elastex.run
    {:reply, ResponseBuilder.build(elastic_response,period),state}
  end

  def handle_call({:put_records,{url,body}},_from,state) do
    body=JSON.encode! body
    {_, result } = Elastex.Web.post(url,body,[{"Content-Type","application/json"}])
    {:reply, result , state}
  end
end
