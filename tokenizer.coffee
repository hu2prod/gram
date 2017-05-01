module = @
# ltrim = (text, subtext)->
#   len = subtext.length
#   loop
#     ch = text[0]
#     if -1 != subtext.indexOf ch
#       text = text.substr 1
#       continue
#     break
#   text


strict_rule = require './strict_rule'
Node = strict_rule.Node

# ###################################################################################################
#  TODO
#  reject token
# ###################################################################################################

class @Token_parser
  name  : ''
  regex   : ''
  atparse : null
  first_letter_list : []
  first_letter_list_discard : {}
  constructor : (name, regex, atparse=null)->
    @name = name
    @regex= regex
    @atparse= atparse
    @first_letter_list = []
    @first_letter_list_discard = {}
  fll_add  : (first_letter_list)->
    @first_letter_list = first_letter_list.split ''
    @
  fll_discard  : (first_letter_list)->
    for ch in first_letter_list.split ''
      @first_letter_list_discard[ch] = true
    @
class @Tokenizer
  parser_list : []
  text    : null
  atparse_unique_check : false
  prepare   : []
  afterparty  : []
  is_prepared : false
  tail_space_len: 0
  ret_access : []
  
  @first_char_table  : {}
  @profile  : false
  @positive_symbol_table = {}
  @non_marked_rules = []
  constructor : ()->
    @parser_list= []
    @prepare  = []
    @afterparty = []
    @first_char_table  = {}
    @positive_symbol_table = {}
    @non_marked_rules = []
  rword : (text, case_sensitive = false)->
    text = RegExp.quote text
    @parser_list.push new module.Token_parser 'reserved_word', new RegExp "^"+text, if case_sensitive then '' else 'i'
  set_text:(text)->
    # @text = ltrim(text, ' \t')
    @text = text
  try_regex   : (regex)->
    regex.exec(@text)
  regex     : (regex)->
    ret = regex.exec(@text)
    return null if !ret
    @text = @text.substr ret[0].length
    @tail_space_len = /^[ \t]*/.exec(@text)[0].length
    # @text = ltrim(@text, ' \t')
    @text = @text.substr @tail_space_len
    ret
  initial_prepare_table: ()->
    @positive_symbol_table = {}
    @non_marked_rules = []
    for v in @parser_list
      if v.first_letter_list.length > 0
        for ch in v.first_letter_list
          @positive_symbol_table[ch] ?= []
          @positive_symbol_table[ch].push v
      else
        @non_marked_rules.push v
    
    @is_prepared = true
    return
  prepare_table : ()->
    @first_char_table = {}
    for i in [0 ... @text.length]
      ch = @text[i]
      continue if @first_char_table[ch]?
      list = []
      if @positive_symbol_table[ch]?
        for v in @positive_symbol_table[ch]
          list.push v
      for v in @non_marked_rules
        list.push v unless v.first_letter_list_discard[ch]?
      @first_char_table[ch] = list
    return
  reject : ()->
    @need_reject = true
    new_loc_arr = []
    for v in @loc_arr
      continue if v == @reject_target
      new_loc_arr.push v
    # preserve loc_arr reference
    # can't simply do @loc_arr = new_loc_arr
    while @loc_arr.length
      @loc_arr.pop()
    for v in new_loc_arr
      @loc_arr.push v
    return
  go      : (text)->
    for v in @prepare
      v @
    @set_text text
    @initial_prepare_table() if !@is_prepared
    @prepare_table()
    add_base = (add_list)->
      node = add_list[0].clone()
      node.mx_hash.hash_key = 'base'
      add_list.push node
      return
    @ret_access = ret = []
    while @text.length > 0
      found = false
      @loc_arr = loc_arr = []
      # for v in @parser_list # плесень для отладки
      for v in @first_char_table[@text[0]]
        # ###################################################################################################
        #  Добавить проверку первой буквы
        # ###################################################################################################
        reg_ret = @try_regex v.regex # can be optimized (inline)
        if reg_ret?
          node = new Node
          node.mx_hash.hash_key = v.name
          node.regex = v.regex # parasite
          node.value = reg_ret[0]
          node.atparse = v.atparse if v.atparse?
          loc_arr.push node
      throw new Error "can't tokenize '#{@text.substr(0,100)}'..." if loc_arr.length == 0
      loop
        @need_reject = false
        @loc_arr_refined = loc_arr_refined = []
        max_length = 0
        for v in loc_arr
          max_length = v.value.length if max_length < v.value.length
        for v in loc_arr
          loc_arr_refined.push v if v.value.length == max_length
        
        ret_proxy_list = []
        for v in loc_arr_refined
          @reject_target = v
          ret_proxy_list.push ret_proxy = []
          if v.atparse?
            v.atparse(@, ret_proxy, v)
          else
            ret_proxy.push [v]
        
        if @need_reject
          continue
        break
      
      @regex loc_arr_refined[0].regex if loc_arr_refined[0].regex
      
      for v in loc_arr_refined
        v.mx_hash.tail_space = +@tail_space_len
      
      if @atparse_unique_check
        if ret_proxy_list.length > 1
          puts loc_arr_refined
          throw new Error "atparse unique failed. Multiple regex pretending"
      else if ret_proxy_list.length > 1
        united_length = ret_proxy_list[0].length # token list length
        if united_length>1
          throw new Error("united_length > 1 not implemented")
        for v in ret_proxy_list
          if v.length != united_length
            puts ret_proxy_list
            throw new Error("no united length")
      
      if ret_proxy_list.length > 1
        add_list = []
        # only for united_length == 1
        for v in ret_proxy_list
          list = v[0]
          if list
            for v2 in list
              add_list.push v2
        if add_list.length
          add_base add_list
          ret.push add_list 
      else if ret_proxy_list.length == 1
        list = ret_proxy_list[0]
        if list.length == 1
          add_list = list[0]
          add_base add_list
          ret.push add_list
        else
          for v in list
            ret.push v
      else
        throw new Error("ret_proxy_list.length == 0 -> not parsed")
    for v in @afterparty
      v(@, ret)
    ret

