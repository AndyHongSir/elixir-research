defmodule ResponseBuilder do
  require OK
  import  OK, only: ["~>>": 2]

  def build(response, period) do
	{:ok, %{:response         => response,
  		  	:period           => period,
			:aggregations     => [],
			:phases_raw       => [],
			:consumption_raw  => [],
			:consumption      => :nil,
			:phases           => :nil,
			:ts_list          => [],
			:keys             => [],
			:json             => :nil,
  			:error            => :nil}}
  	~>> get_aggregations
  	~>> get_keys
	~>> decompose_aggregations
	~>> get_consumption
	~>> get_phases
	~>> construct_json
	~>> return_response
  end

  defp get_aggregations(%{:response => response}=state) do
	aggs = for map <- response.body["responses"], do: map["aggregations"]
	OK.success %{state | :aggregations => aggs}
  end

  defp get_keys(%{:aggregations => aggs}=state) do
	keys = List.foldl(aggs,[],fn(x,acc) -> [key] = Map.keys(x); [key|acc] end)
	OK.success %{state | :keys => keys}
  end

  defp decompose_aggregations(%{:aggregations => aggregations,
								:keys         => keys} = state) do
	{consumption,phases,ts_list} = read_aggregations(aggregations,keys,[],[],[])
	OK.success %{state |
				 :consumption_raw => consumption,
				 :phases_raw      => phases,
				 :ts_list         => ts_list}
  end

  defp read_aggregations([], _,consumption,phases,ts_list) do
	{:lists.keysort(1,consumption),:lists.keysort(1,phases),:lists.reverse(:lists.sort(ts_list))}
  end
  defp read_aggregations([response | responses],keys, consumption,phases,ts_list) do
	case get_aggregation_value(response,keys) do
	  {ts,_,_} = val  ->
		ts_list1 = ts_list ++ [ts]
		read_aggregations(responses,keys,[val|consumption],phases,Enum.uniq(ts_list1))
	  {ts,_,_,_ } = val  ->
		ts_list1 = ts_list ++ [ts]
		read_aggregations(responses,keys,consumption,[val|phases],Enum.uniq(ts_list1))
	end
  end

  defp get_aggregation_value(aggregation,[key|keys]) do
	case aggregation[key] do
	  nil   ->
		get_aggregation_value(aggregation,keys)
	  value0 ->
		value1 = Map.to_list(value0)
		[{key,val}]  =
		  :lists.flatten(for {"doc_count",_} = i <- value1, do: value1 -- [i])
		[p,k,ts] = String.split key,"."
		case p do
		  "avg" ->
			{ts,k,val["value"]}
		  _  ->
			{ts,p,k,val["avg"]}
		end
	end
  end

  defp get_consumption(%{:consumption_raw => resp,
						 :ts_list         => ts_list,
						 :period          => period}=state) do
	OK.success %{state | :consumption => get_consumption(resp, ts_list,period)}
  end
  defp get_consumption(resp, ts_list,period) do
	get_consumption(resp,ts_list,period,[])
  end

  defp consumption_val(list,dim) do
	case Enum.uniq(Enum.filter(list,
			  fn({_,d,_}) ->  d == dim end))
	  do
	  [{_,_,a_lte}] ->
		a_lte
	  [] ->
		0
	end
  end

  defp get_consumption(resp,[ts_lte | ts_rest],period,acc) do

	ts_gte   = QueryBuilder.prev_ts(String.to_integer(ts_lte),QueryBuilder.period_encoder(period))
	list_lte = Enum.filter(resp,fn({x,_,_}) -> x == ts_lte end)
	list_gte = Enum.filter(resp,fn({x,_,_}) -> x == Integer.to_string(ts_gte) end)
	a_lte  = consumption_val(list_lte,"+A")
	a_gte  = consumption_val(list_gte,"+A")
	ri_lte = consumption_val(list_lte,"+Ri")
	ri_gte = consumption_val(list_gte,"+Ri")

	{a,ri}
	= case a_lte == :nil or a_gte == :nil or ri_lte == :nil or ri_gte == :nil do
		true  ->
		  {nil,nil}
		false ->
		{:erlang.float_to_binary(Float.floor((a_lte  - a_gte)),
			decimals: 2),
		 :erlang.float_to_binary(Float.floor((ri_lte - ri_gte)),
		   decimals: 2)}
			 end
	# in order to calculate the consumption we need one timestamp period more.
	# so we neeed to remove the that result
	case a_gte do
	  0 ->
		get_consumption(resp,ts_rest,period, acc)
	  _ ->
		get_consumption(resp,ts_rest,period,
		  [{ts_lte,%{"+A" => a, "+Ri" => ri}} | acc])
	end
  end
  defp get_consumption(_,[],_,acc) do
	acc
  end

  defp get_phases(%{:phases_raw  => resp,
					:ts_list     => ts_list}=state) do
	OK.success %{state | :phases => get_phases(resp, ts_list)}
  end
  defp get_phases(resp, ts_list) do
	get_phases(resp,ts_list,[])
  end

  defp get_phases(_, [], acc) do
	acc
  end

  defp get_phases(resp, [ts | ts_rest], acc) do
	phases_data = Enum.filter(resp, fn({x,_,_,_}) ->  x == ts end)
	l1_pre = Enum.filter(phases_data, fn({_,phase,_,_}) -> phase == "l1" end)
	l2_pre = Enum.filter(phases_data, fn({_,phase,_,_}) -> phase == "l2" end)
	l3_pre = Enum.filter(phases_data, fn({_,phase,_,_}) -> phase == "l3" end)
	l1 = List.foldl(l1_pre, [], fn({_,_,dim,val}, acc) -> [{dim,val}| acc] end)
	l2 = List.foldl(l2_pre, [], fn({_,_,dim,val}, acc) -> [{dim,val}| acc] end)
	l3 = List.foldl(l3_pre, [], fn({_,_,dim,val}, acc) -> [{dim,val}| acc] end)
	case phases_data do
	  [] ->
		get_phases(resp, ts_rest, acc)
	  _ ->
		get_phases(resp, ts_rest, [{ts, %{:l1 => l1,
										  :l2 => l2,
										  :l3 => l3}} | acc])
	end
  end

  defp construct_json(%{:phases      => phases,
						:consumption => consumption}=state) do
	OK.success %{state |:json => construct_json(consumption,phases)}
  end
  defp construct_json(consumption,phases) do
	construct_json(consumption,phases,[])
  end

  defp construct_json([{ts1,consump} | consumption],[{_,phase} | phases],map_list) do
	prep_phases =
	fn(n) ->
	  List.foldl(phase[n],%{},fn({k,val},acc) -> Map.put_new(acc,k,val) end)
	end
	map = %{"root" => [%{"name"      => "ceh1",
						 "timestamp" => ts1,
						 "+A"        => consump["+A"],
						 "+Ri"       => consump["+Ri"],
						 :l1         => prep_phases.(:l1),
						 :l2         => prep_phases.(:l2),
						 :l3         => prep_phases.(:l3)}]}
	construct_json(consumption,phases,[JSON.encode(map) | map_list])
  end

  defp construct_json([],[],acc) do
	acc
  end

  defp return_response(%{:json => json}) do
	{:ok, json}
  end

end
