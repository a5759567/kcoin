module HistoryHelpers

  include UserAppHelpers
  include FabricHelpers
  include GithubHelpers

  def get_history(user_id)
    # get user`s all project histroy
    result = get_list_by_user(user_id)

    result[:UserId] = user_id
    result
  end

  def get_history_by_project(symbol)
    resp = query_history(symbol)
    list = JSON.parse(resp['payload'])
    handle_history(list)
  end

  def get_kcoin_history(eth_account)
    resp = query_history(settings.kcoin_symbol)
    list = JSON.parse(resp['payload'])
    result = {}
    history = []
    list.to_enum.with_index.reverse_each do |item, index|
      tmp = item['Value'] || {}
      event = GithubEvent.first(transaction_id: item['TxId'])
      value = tmp['BalanceOf'] || {}
      amount = value[eth_account.to_s]
      next if event.nil?
      record = {}
      record[:KCoin] = amount
      record[:TokenSymbol] = tmp['TokenSymbol']
      record[:EventName] = event[:github_event]
      record[:Date] = DateTime.parse(item['Timestamp']).strftime('%m.%d')
      record[:Year] = DateTime.parse(item['Timestamp']).strftime('%y')
      record[:Time] = DateTime.parse(item['Timestamp']).strftime('%y.%m.%d')

      record[:ChangeNum] = if index > 0
                             record[:KCoin] - ((list[index - 1] || {})['Value'] || {})['BalanceOf'].values[0]
                           else
                             record[:KCoin]
                           end
      history << record
    end
    result[:History] = history
    result[:KCoin] = query_balance(settings.kcoin_symbol, eth_account)

    result
  end

  def handle_history(list)
    result = {}
    history = []
    list.to_enum.with_index.reverse_each do |item, index|
      event = GithubEvent.first(transaction_id: item['TxId'])
      next if event.nil?
      record = {}
      record[:EventName] = event[:github_event]
      record[:KCoin] = (item['Value'] || {})['BalanceOf'].values[0]
      record[:TokenSymbol] = (item['Value'] || {})['TokenSymbol']
      record[:Date] = DateTime.parse(item['Timestamp']).strftime('%m.%d')
      record[:Year] = DateTime.parse(item['Timestamp']).strftime('%y')
      record[:Time] = DateTime.parse(item['Timestamp']).strftime('%y.%m.%d')

      record[:ChangeNum] = if index > 0
                             record[:KCoin] - ((list[index - 1] || {})['Value'] || {})['BalanceOf'].values[0]
                           else
                             record[:KCoin]
                           end
      history << record
    end

    result[:KCoin] = (history[0] || {})[:KCoin]
    result[:History] = history

    result
  end

  def get_list_by_user(user_id)
    project_list = User[user_id].projects
    result = Hash.new
    list = []

    kcoin = query_balance(settings.kcoin_symbol, User[user_id].eth_account)
    project_list.each do |project|
      result = get_history_by_project(project.symbol)
      list.concat(result[:History])
    end

    result[:History] = list
    result[:KCoin] = kcoin
    result
  end

  def group_history(history)
    result = []
    array = history[:History].group_by {|h| h[:TokenSymbol]}.values
    array.each do |item|
      record = {}
      record[:KCoin] = (item[0] || {})[:KCoin]
      record[:TokenSymbol] = (item[0] || {})[:TokenSymbol]
      record[:History] = item
      project = Project.first(symbol: record[:TokenSymbol])
      next if project.nil?
      record[:ProjectName] = project[:name]
      record[:Img] = project[:img]
      result << record
    end
    result
  end
end
