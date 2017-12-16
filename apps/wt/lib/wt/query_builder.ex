defmodule QueryBuilder do
  require OK
  import  OK, only: ["~>>": 2]
  @moduledoc """
  Documentation for QueryBuilder
  """

  defmacro __hours__ do
    quote do: 3600000000
  end

  defmacro __days__ do
    quote do: __hours__ * 24
  end

  defmacro __minute__ do
## one minute
    quote do: 1000000 * 60
  end

  defmacro __seconds__ do
    ## one seconds
    quote do: 4000000
  end

  def multi_query(index,type,lte,gte,period) do
    mquery_set = get_mquery_set()
    milti_query(index,type,lte,gte,period,mquery_set,[])
  end

  def milti_query(_,_,_,_,_,[],mquery) do
	mquery
  end
  def milti_query(index,type,lte,gte,period,[{phase,dimension,query_type} | queries],mquery) do
	query = build_single_query(index,type,phase,dimension,lte,gte,period,query_type)
	milti_query(index,type,lte,gte,period,queries,query ++ mquery)
  end

  def build_single_query(index,type,phase,dimension,lte,gte,period,query_type) do
  	{:ok, %{:ts_list       => [],
  			:body_list     => [],
  			:query_type    => query_type,
  			:query         => [],
  			:index         => index,
  			:type          => type,
  			:phase         => phase,
  			:dimension     => dimension,
  			:lte           => lte,
  			:gte           => gte,
  			:period        => period,
  			:query_name    => :nil,
  			:error         => :nil}}
  	~>> get_ts_list
  	~>> get_body_list
  	~>> build_query
  	~>> return_query
  end

  defp get_ts_list(%{:query_type => query_type,
					 :lte        => lte,
					 :gte        => gte,
					 :period     => period}=builder) do
	ts_list = ts_list_builder(get_breaker(query_type),lte,gte,period_encoder(period))
	OK.success %{builder | :ts_list => ts_list}
  end

  def get_body_list(%{:query_type => query_type,
					  :ts_list    => ts_list,
					  :dimension  => dimension,
					  :phase      => phase}=builder) do
	body_list = construct_body(query_type,ts_list,dimension,phase)
	OK.success %{builder | :body_list => body_list}
  end

  def build_query(%{:body_list => body_list,
					:index     => index,
					:type      => type}=builder) do
	query = construct_query(body_list,index,type)
	OK.success %{builder | :query => query}
  end

  def return_query(%{:query => query}) do
	query
  end

  defp construct_body(strategy,ts_list_builder,dimension, phase) do
	construct_body(strategy,ts_list_builder,dimension, phase,[])
  end

  defp construct_body(strategy,[{gte,lte} | timestamps],dimension,phase,acc) do
	body = body_strategy({strategy,gte,lte,phase,dimension})
	construct_body(strategy,timestamps, dimension, phase, [body | acc])
  end
  defp construct_body(_,[],_,_,acc) do
	acc
  end

  defp construct_query(body_list, index, type) do
	construct_query(body_list,index, type,[])
  end

  defp construct_query([body | bodies],index,type, acc) do
	query = Elastex.Search.query(body, index , type)|> Elastex.Search.params([size: 0])
	construct_query(bodies,index,type, [query | acc])
  end

  defp construct_query([],_,_, acc) do
	acc
  end

  ### -------------------------------------
  ###   Timestamp list builder
  ### -------------------------------------
  defp ts_list_builder(break,from,to,period) do
	ts_list_builder(break,from,to,period,[])
  end

  defp ts_list_builder(_,from,to,_period,acc) when from == to do
	acc
  end
  defp ts_list_builder(:minus_one_period,from,to,period,acc) when from == (to - period) do
   	acc
  end
  defp ts_list_builder(:minus_one_period = break,from,to,period,acc) do
	previous_ts1 = prev_ts(from,period)
	previous_ts2 = prev_ts(previous_ts1,period_encoder(:seconds))
	from1 = prev_ts(from,period_encoder(:seconds))
	ts_list_builder(break,previous_ts1,to,period,[{previous_ts1, previous_ts2}, {from,from1} | acc])
  end

  defp ts_list_builder(break,from,to,period,acc) do
	previous_ts = prev_ts(from,period)
	ts_list_builder(break,previous_ts,to,period,[{previous_ts,from} | acc])
  end

  ### -------------------------------------
  ###  Get breaker
  ### -------------------------------------
  defp get_breaker(:avg) do
	:minus_one_period
  end
  defp get_breaker(:stats) do
	:nil
  end

  ### -------------------------------------
  ###  Get previous period
  ### -------------------------------------
  def prev_ts(ts, period) do
	ts - period
  end

  ### -------------------------------------
  ###  Period encoder
  ### -------------------------------------
  def period_encoder(:hours) do
    __hours__()
  end
  def period_encoder(:days) do
    __days__()
  end
  def period_encoder(:minute) do
    __minute__()
  end
  def period_encoder(:seconds) do
    __seconds__()
  end

  ### -------------------------------------
  defp body_strategy({:avg,lte,gte,_,dimension}) do
	%{"size": 0,"aggs":
	  %{"root.#{dimension}":
		%{"filter": %{"range":
					  %{"root.timestamp":
						%{"gte": gte ,"lte": lte}}},
		  "aggs": %{"avg.#{dimension}.#{lte}":
					%{"avg": %{"field": "root.#{dimension}"}}}}}}
  end
  defp body_strategy({:stats,gte,lte,phase,dimension}) do
	%{"size": 0,"aggs":
  	  %{"root.#{phase}.#{dimension}":
  		%{"filter": %{"range":
  					  %{"root.timestamp":
  						%{"gte": gte, "lte": lte}}},
  		  "aggs": %{"#{phase}.#{dimension}.#{lte}":
					%{"stats": %{"field": "root.#{phase}.#{dimension}"}}}}}}
  end

  def convert_date_time(time) do
	newts = String.to_integer(String.slice(Integer.to_string(time),0..9))
	{:ok,date} = DateTime.from_unix newts
	{date.day,date.hour,date.minute}
  end

  def get_mquery_set() do
	[{:nil,"+A",:avg},
	 {:nil,"+Ri",:avg},
	 {"l1","cos",:stats},
	 {"l2","cos",:stats},
	 {"l3","cos",:stats},
	 {"l1","volts",:stats},
	 {"l2","volts",:stats},
	 {"l3","volts",:stats},
	 {"l1","amperes",:stats},
	 {"l2","amperes",:stats},
	 {"l3","amperes",:stats},
	 {"l1","kw",:stats},
	 {"l2","kw",:stats},
	 {"l3","kw",:stats},
	 {"l1","kv",:stats},
	 {"l2","kv",:stats},
	 {"l3","kv",:stats}
	]
  end
end
