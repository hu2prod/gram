# ###################################################################################################
#  TODO
#  выпилить legacy code
#     остались proxy_*
#  запилить постпроцессинг по Node list
#  запилить дебаг вида "почему не сработало вот это правило"
#     можно сказать, что почти сделано
#  запилить фичи regexp * + ? {[n],[n]}
#  запилить фичи regexp вида #word_comma_star = #word (, #word)*
#  запилить автоматическое создание tokenizer regexp'а (то, что я сейчас делаю для word ручками)
#  possible bug a b? b .strict('#b[0]==#b[1]') # номера сдвигаются если в правиле отсутствует ?
#  починить autoassign
# ###################################################################################################
module = @

str_replace = (search, replace, str)-> str.split(search).join(replace)
shuffle = (a)->
  for i in [a.length ... 0] by -1
    j = Math.floor Math.random() * i
    x = a[i - 1]
    a[i - 1] = a[j]
    a[j] = x
  a


strict_rule = require './strict_rule'
Node = strict_rule.Node
mx_rule_parser    = strict_rule.mx_rule_parser
strict_rule_parser  = strict_rule.strict_rule_parser
mx_node = strict_rule.mx_node
Mx_rule = strict_rule.Mx_rule

explicit_list_generator = (require './explicit_list_generator').explicit_list_generator

gram_debug_hash =
  gdtc : 0
@gram_debug = false
_gram_debug_tracer_counter = 0
_gram_debugger_points = {}
@gram_debug_set_gdtc = (t)->
  _gram_debugger_points[t] = true
@gram_debug_tracer = ()->
  gram_debug_hash.gdtc = _gram_debug_tracer_counter++ # короткое имя
  if _gram_debugger_points[gram_debug_hash.gdtc]?
    debugger
  gram_debug_hash.gdtc
   
class Gram_console
  list  : []
  constructor :()->
    @clear()
  clear   : ()->
    @list   = []
  log   : (obj)->
    @list.push obj
    console.log obj.msg
  select  : (_where, console_log = true) ->
    ret = @list
    for key,value of _where
      new_ret = []
      for v in ret
        new_ret.push v if v[key] == value
      ret = new_ret
    if console_log
      for v in ret
        console.log v.msg
    ret
@gram_console = new Gram_console

class @Gram_rule
  ret_name  : null
  signature   : ''
  sequence  : []
  mx_hash   : {}
  strict_list : []
  is_pure   : false
  hash_ref  : {}
  constructor : ()->
    @sequence   = []
    @mx_hash    = {}
    @strict_list  = []
    @hash_ref   = {}
  
  mx      : (str_list) ->
    # @signature += ".mx('#{str_list}')" # KEEP. потом как-то решим как коротко передать сигнатуру
    # @mx_hash = mx_rule_parser.parse_as_arr str_list
    res = mx_rule_parser.parse_as_arr str_list
    for k,v of res
      @mx_hash[k] = v
    @
  add_ref   : (ref) ->
    refference =
      name   : ref
      position : null
    
    @hash_ref[ref] ?= []
    @hash_ref[ref].push refference
    refference
  strict    : (str_list) ->
    @signature += ".strict('#{str_list}')"
    athis = @
    pure_handler = (v)->
      if ret = v == 'pure'
        athis.is_pure = true
      ret
    res = strict_rule_parser.parse_as_arr str_list, [pure_handler]
    for v in res
      @strict_list.push v
    @
  gram_unescape: (v) ->  
    v = str_replace '[PIPE]',   '|', v
    v = str_replace '[QUESTION]','?', v
    v = str_replace '[DOLLAR]', '$', v # нужно в случае конструкций ${}, когда нельзя отделить $ от токена
    v = str_replace '[HASH]',   '#', v
  gram_escape: (v) ->
    v = str_replace '|', '[PIPE]',   v
    v = str_replace '?', '[QUESTION]',   v
    v = str_replace '$', '[DOLLAR]', v
    v = str_replace '#', '[HASH]',   v
  parse_rule  : (str_pipe_list) ->
    @signature += "#{str_pipe_list} "
    ret_list = []
    list = str_pipe_list.split '|'
    for v,k in list
      v = @gram_unescape v
      if v[0] == '#' and v.length > 1
        ref = @add_ref v.substr 1
        ref.position = @sequence.length
        ret_list.push ref
      else if v[0] == '$' and v.length > 1
        v = v.substr 1
        ret_list = @sequence[v-1]
        if !ret_list
          console.log gram_debug_hash.errordump = @ # на объект, ебись сам
          throw new Error "backtrace #{v} fails. For more information see errordump"
        @strict_list.push 
          position_type   : 'bin_op'
          value       : '=='
          left      : 
            position_type   : 'identifier'
            id_type     : '$'
            value       : v
          right       : 
            position_type   : 'identifier'
            id_type     : '$'
            value       : k+1
        
      else
        
        reg_ret = /^\"([^\"]*)\"/.exec(v)
        reg_ret = /^\'([^\']*)\'/.exec(v) if !reg_ret
        if reg_ret
          ret_list.push reg_ret[1]
        else
          ret_list.push v
    @sequence.push ret_list
    return
  # ###################################################################################################
  exec_rule_positions    : []
  exec_hash_rule_positions : {}
  check_fail_reason : null
  fill_exec_positions : (value_array) ->
    @exec_rule_positions = value_array
    return
  # ###################################################################################################
  #	TODO Переделать
  #	TODO optimize. regular call
  #   try remove hash logic from strict_rule
  #   try replace fill_exec_positions to direct
  #   try replace t_paired_value == 'string' -> bool(is_paired_string)/(enum_const)
  #   try remove gram_debug (влияет ли наличие левого кода на выполнение)
  #   think. initial check is a little bit messy. Need more C++-friendly code
  # ###################################################################################################
  check_and_mix : (value_array) ->
    gram_debug_tracer() if module.gram_debug
    @fill_exec_positions(value_array)
    
    return null if @sequence.length != value_array.length
    for list,k in @sequence
      paired_value = value_array[k]
      if paired_value.mx_hash? and paired_value.mx_hash.hash_key?
        if paired_value.mx_hash.hash_key != 'base'
          paired_value = paired_value.mx_hash.hash_key
          t_paired_value = 'object'
        else
          paired_value = paired_value.value
          t_paired_value = 'base'
      else
        paired_value = paired_value.value
        t_paired_value = 'string'
      found_cmp  = false
      throw new Error "gram sequence type fail #{@ret_name}" if typeof list == 'string'
      for v in list
        if t_paired_value == 'base'
          found_cmp = true if v == paired_value or v.name == 'base'
        else if typeof v == t_paired_value
          if t_paired_value == 'string'
            found_cmp = true if v == paired_value
          else
            found_cmp = true if v.name == paired_value
          
      if !found_cmp
        if module.gram_debug
          value_array_str = (v.value for v in value_array).join ' | '
          list_str = ((if v.name then "##{v.name}" else v) for v in list).join ','
          msg = str_pad(_gram_debug_tracer_counter,5)
          msg += "rule #{str_pad(@signature, 90)}"
          msg += "rejected for #{str_pad('\''+value_array_str+'\'', 20)}"
          msg += "reason sequence[#{k}]: paired_value=#{str_pad('\''+paired_value+'\'', 20)}"
          msg += "not found in list '#{list_str}'"
          @gram_console.log
            rule      : @
            value_array   : value_array
            value_array_str : value_array_str
            vastr       : value_array_str # short
            list_str    : list_str
            msg       : msg
        return null
    # unless opt.no_strict_check # достаточно заметно замедляет обычные проходы, потому выпилено TODO (templated function решат эту проблему)
    for strict_rule,k in @strict_list
      if !strict_rule.check @exec_rule_positions, @exec_hash_rule_positions
        if module.gram_debug
          value_array_str = (v.value for v in value_array).join ' | '
          msg = str_pad(_gram_debug_tracer_counter,5)
          msg += "rule #{str_pad(@signature, 90)}"
          msg += "rejected for #{str_pad('\''+value_array_str+'\'', 20)}"
          msg += "reason strict_rule[#{k}] : false"
          @gram_console.log
            rule      : @
            value_array   : value_array
            value_array_str : value_array_str
            vastr       : value_array_str # short
            msg       : msg
        return null
    
    ret = mx_node @mx_hash, @exec_rule_positions, signature: @signature
    values = []
    for v in value_array
      values.push v.value unless v.value == ''
    
    ret.rule = @
    ret.value_array     = value_array
    ret.value         = values.join ' '
    ret.mx_hash.hash_key  = @ret_name
    if module.gram_debug
      value_array_str = (v.value for v in value_array).join ' | '
      msg = str_pad(_gram_debug_tracer_counter,5)
      msg += "rule #{str_pad(@signature, 90)}"
      msg += "accepted for #{str_pad('\''+value_array_str+'\'', 20)}"
      @gram_console.log
        rule      : @
        value_array   : value_array
        value_array_str : value_array_str
        vastr       : value_array_str # short
        ret       : ret
        msg       : msg
    
    ret
  check_path_and_mix : (value_array) ->
    gram_debug_tracer() if module.gram_debug
    value_array_refined = (v.list for v in value_array)
    
    ret = []
    for loc_value_array in explicit_list_generator.gen value_array_refined
      loc = @check_and_mix loc_value_array
      ret.push loc if loc
    ret
  optimize : ()->
    for k,v of @mx_hash
      v.value.optimize_run [], @hash_ref
    for v in @strict_list
      v.optimize_run [], @hash_ref
    @rebuild_signature()
    return
  rebuild_signature : ()->
    sig_list = []
    for list in @sequence
      pipe_list = []
      for v in list
        pipe_list.push "##{v.name}" if v.name?
      sig_list.push pipe_list.join '|'
    
    strict = ''
    strict = (strict_rule.signature for strict_rule in @strict_list).join ' ' if @strict_list.length > 0
    strict = ".strict(#{strict})" if strict
    @signature = (sig_list.join ' ') + (strict)
  
class Gram_rule_parser
  parse : (ret_name, str_list, opt = {})->
    implicit_list = []
    proxy_rule_key_list = {}
    hash_ref = false
    has_raw = false
    split_list = str_list.split ' '
    for v in split_list
      if ((v[0] == '#' or v[0] == '$') and (v.length>1))
        hash_ref = true
      else
        has_raw = true
    if hash_ref and has_raw
      for v,k in split_list
        if !((v[0] == '#' or v[0] == '$') and (v.length>1))
          if -1 != v.indexOf '|'
            found_clean = false
            found_position = false
            found_hash = false
            for v2 in v.split('|')
              found_clean = true if v2[0] != '$' and v2[0] != '#'
              found_position = true if v2[0] == '$'
              found_hash = true if v2[0] == '#'
            if found_clean and (found_position or found_position)
              throw new Error "piped and mixed not implemented in single gram rule '#{str_list}'" if -1 != v.indexOf '|'
            # puts "Warning rule '#{str_list}' can be processed invalid way"
          proxy_key = "proxy_#{v}"
          proxy_rule_key_list[proxy_key] = v
          split_list[k] = "#"+proxy_key
    for v in split_list
      loc = []
      if (v[0] == '#' or v[0] == '$') and v[v.length-1] == '?'
        v = v.substr 0, v.length-1
        loc.push null
      loc.push v
      implicit_list.push loc
    rule_list = []
    for list in explicit_list_generator.gen implicit_list
      rule = new module.Gram_rule
      rule.ret_name = ret_name
      rule.debug = true if opt.debug
      for v in list
        rule.parse_rule v if v?
      rule_list.push rule if rule.sequence.length > 0
    proxy = 
      proxy_rule_key_list : proxy_rule_key_list
      rule_list : rule_list
      mx    : ()->
        for _v in rule_list
          _v.mx.apply _v, arguments
        proxy
      strict  : ()->
        for _v in rule_list
          _v.strict.apply _v, arguments
        proxy
    proxy
@gram_rule_parser = new Gram_rule_parser
# ###################################################################################################

class @Gram
  @magic_attempt_limit : 20
  # currently fastest flags
  mode_full  : false
  mode_optimize: true
  rule_hash  : {}
  rule_list  : []
  proxy_rule_hash: {}
  debug    : false
  use_proxy  : true # gram определяет правила для proxy, tokenizer не вмешивается | gram не определяет правила для proxy, tokenizer формирует proxy
  constructor  : ()->
    @rule_hash = {}
    @rule_list = []
    @proxy_rule_hash = {}
  rule : (ret, str_list, opt = {}) ->
    proxy = module.gram_rule_parser.parse ret, str_list, opt
    @rule_hash[ret] ?= []
    if @use_proxy
      for v_ret,raw of proxy.proxy_rule_key_list
        continue if @proxy_rule_hash[raw]?
        @proxy_rule_hash[raw] = true
        proxy2 = module.gram_rule_parser.parse v_ret, raw, opt
        rule = proxy2.rule_list[0]
        @rule_hash[v_ret] ?= []
        @rule_hash[v_ret].push rule
        @rule_list.push rule
    for v in proxy.rule_list
      @rule_hash[ret].push v
      @rule_list.push v
    proxy
  rule_direct : (ret, value) ->
    rule = new module.Gram_rule
    rule.ret_name = ret
    rule.sequence.push [value]
    @rule_hash[ret] ?= []
    @rule_hash[ret].push rule
    @rule_list.push rule
    rule
  # ###################################################################################################
  #	REVIEW
  # ###################################################################################################
  get_all_combos : (sequence) ->
    multiplier = [ [] ]
    for list in sequence
      multiplier_next = []
      for l_v in list
        for m_v in multiplier
          arr = clone m_v
          arr.push l_v
          multiplier_next.push arr
      multiplier = multiplier_next
    return multiplier
  gen_random_rule_list : (rule_list) ->
    rule_list = shuffle(rule_list)
    for limit in [1..Gram.magic_attempt_limit] # нужно т.к. есть nested вызов gen_random, который может выдавать как удачные, так и неудачные варианты
      for rule in rule_list
        combo_list = @get_all_combos(rule.sequence)
        combo_list = shuffle combo_list
        for list in combo_list
          ret = []
          for selected in list
            if typeof selected == 'string'
              ch = new Node
              ch.value = selected
              ret.push ch
            else
              loc = @gen_random(selected.name) # TODO как-то учесть правила, по которым должен строится данный gen_random
              if loc == null
                ret = null
                break
              ret.push loc
          
          continue if ret == null
          mix_res = rule.check_and_mix ret
          return mix_res if mix_res
    return null
  gen_random : (key) ->
    pure_rule_list = []
    nonpure_rule_list = []
    if typeof key == 'string'
      rule_list = @rule_hash[key]
      throw new Error "there is not rules for #{key}" if !rule_list
      
      for v in rule_list
        if v.is_pure
          pure_rule_list.push v
        else
          nonpure_rule_list.push v
    else
      nonpure_rule_list = [key]
    res = @gen_random_rule_list(nonpure_rule_list)
    return res if res
    @gen_random_rule_list(pure_rule_list)
  # ###################################################################################################
  #	parse text
  # ###################################################################################################
  
  rule_by_length_list  : []
  checked_intervals    : {}
  parse_prepare : () ->
    @rule_by_length_list  = []
    @rule_by_length_list[1] ?= []
    @checked_intervals    = {}
    for v in @rule_list
      @rule_by_length_list[v.sequence.length] ?= []
      @rule_by_length_list[v.sequence.length].push v
    return
  parse : (text, opt = {}) ->
    text = strtolower text if opt.lower?
    str_list = ',.';
    for v in [0 .. str_list.length]
      char = str_list[v]
      text = str_replace(char, " #{char} ", text)
    list = text.split(' ')
    refine_list = []
    for v in list
      refine_list.push v unless v == ''
    refine_list = opt.post_processor refine_list if opt.post_processor?
    @parse_text_list refine_list, opt
  stat_reset: ()->
    @stat_merge_pair = 0
    @stat_merge_pair_skip = 0
    @stat_merge_pair_mix = 0
    @stat_merge_pair_mix_hit = 0
    @stat_ext    = 0
  stat : ()->
    puts "stat_cycle_counter       = #{@stat_cycle_counter}"
    puts "stat_merge_pair          = #{@stat_merge_pair}"
    puts "stat_merge_pair_skip     = #{@stat_merge_pair_skip}"
    puts "stat_merge_pair_mix      = #{@stat_merge_pair_mix}"
    puts "stat_merge_pair_mix_hit  = #{@stat_merge_pair_mix_hit}"
    puts "stat_ext                 = #{@stat_ext}"
    puts "hit/mix                  = #{@stat_merge_pair_mix_hit/@stat_merge_pair_mix}"
  parse_text_list : (list, opt={}) -> # может хавать list of node_list
    @stat_reset()
    @optimize() if @mode_optimize
    @parse_prepare_binary()
    @parse_list_binary list, opt
      
  # ###################################################################################################
  #	ускоритель для парсинга (устарело, переделать)
  # ###################################################################################################
  # accelerator_save  : ()->
    # JSON.stringify @checked_intervals
  # accelerator_load  : (t)->
    # @checked_intervals = JSON.parse t
  # ###################################################################################################
  #  новый режим работы
  # ###################################################################################################
  split_uid : 0
  swapped_t1 : null
  swapped_t2 : null
  set_new_targets_for_2pos_strict_rule : (rule, g_rule, t1 = null, t2 = null) ->
    rule = clone rule
    affected = false
    if rule.position_type == 'pre_op'
      [rule.left, affected] = @set_new_targets_for_2pos_strict_rule rule.left, g_rule, t1, t2
    else if rule.position_type == '$position' or rule.position_type == '#position'
      affected = true
      if rule.position_type == '#position'
        # need cast 2 $position
        fetch = g_rule.hash_ref[rule.value]
        if !fetch
          console.log gram_debug_hash.errordump = rule
          throw new Error "#rule #{rule.value} not found. For more information see errordump"
          
        fetch = fetch[if rule.number_access? then rule.number_access - 1 else 0]
        if !fetch
          console.log gram_debug_hash.errordump = rule
          throw new Error "#rule number_access #{rule.number_access} not found. For more information see errordump"
        rule.position_type = '$position'
        rule.value = fetch.position + 1
        rule.number_access = null
      # else if rule.position_type == '$position' # nothing
    # else if rule.position_type == 'constant'
    else if rule.position_type == 'bin_op'
      [rule.left , a1] = @set_new_targets_for_2pos_strict_rule rule.left , g_rule, t1, t2
      [rule.right, a2] = @set_new_targets_for_2pos_strict_rule rule.right, g_rule, t1, t2
      if a1 and a2
        if t1?
          @swapped_t1 = rule.left
          rule.left   = t1
        else
          rule.left  = @shift_abs_positions_for_2pos_strict_rule rule.left, 1
        if t2?
          @swapped_t2 = rule.right
          rule.right  = t2
        else
          rule.right = @shift_abs_positions_for_2pos_strict_rule rule.right, 1
      affected = a1 or a2
      
    [rule, affected]
  shift_abs_positions_for_2pos_strict_rule : (rule, shift) ->
    rule = clone rule
    if rule.position_type == 'pre_op'
      rule.left = @shift_abs_positions_for_2pos_strict_rule rule.left, shift
    else if rule.position_type == '$position' or rule.position_type == '#position'
      if rule.position_type == '#position'
        # need cast 2 $position
        fetch = rule.hash_ref[rule.value]
        if !fetch
          console.log gram_debug_hash.errordump = rule
          throw new Error "#rule #{rule.value} not found. For more information see errordump"
          
        fetch = fetch[if rule.number_access? then rule.number_access - 1 else 0]
        if !fetch
          console.log gram_debug_hash.errordump = rule
          throw new Error "#rule number_access #{rule.number_access} not found. For more information see errordump"
        rule.position_type = '$position'
        rule.value = fetch.position + 1 - shift
        rule.number_access = null
      else if rule.position_type == '$position' # nothing
        rule.value -= shift
    # else if rule.position_type == 'constant'
    else if rule.position_type == 'bin_op'
      rule.left = @shift_abs_positions_for_2pos_strict_rule rule.left, shift
      rule.right= @shift_abs_positions_for_2pos_strict_rule rule.right, shift
      
    rule
  strict_rule_to_bin_rest : (rule, g_rule) ->
    bin = null
    rest = null
    rule = rule.clone()
    list = rule.get_affected_position_list g_rule.hash_ref
    if list.length == 0
      # bin  = rule.clone() # need for mx_hash penetration flag conflict resolve
      rest = rule
    else if list.length == 1
      k = list[0]
      if k <= 1
        bin_pos = [k]
        bin = rule
      else
        rest_pos = [k-1]
        rest = @shift_abs_positions_for_2pos_strict_rule rule, 1
    else if list.length == 2
      [k1, k2] = list
      if    k1 <= 1 and k2 <= 1
        bin = rule
        bin_pos = [k1, k2]
      else if k1 >  1 and k2 >  1
        rest = @shift_abs_positions_for_2pos_strict_rule rule, 1
        rest_pos = [k1-1, k2-1]
      else if k1 <= 1 and k2 >  1
        proxy_name = "proxy_mx_"+(@split_uid++)
        new_first = strict_rule_parser.parse "$1.#{proxy_name}"
        [rest] = @set_new_targets_for_2pos_strict_rule rule, g_rule, new_first, null
        mx_rule = new Mx_rule
        mx_rule.name = proxy_name
        mx_rule.value = @swapped_t1
      else # if k1 > 1 and k2 <= 1
        proxy_name = "proxy_mx_"+(@split_uid++)
        new_second = strict_rule_parser.parse "$1.#{proxy_name}"
        [rest] = @set_new_targets_for_2pos_strict_rule rule, g_rule, null, new_second
        mx_rule = new Mx_rule
        mx_rule.name = proxy_name
        mx_rule.value = @swapped_t2
    else
      throw new Error("can't split rule with '3-position strict_rule'")
    
    bin.rebuild_signature() if bin?
    rest.rebuild_signature() if rest?
    mx_rule.value.rebuild_signature() if mx_rule?
    {
      bin_rule  : bin
      rest_rule   : rest
      bin_pos   : bin_pos
      rest_pos  : rest_pos
      add_mx_rule : mx_rule
    }
  split_rule_left : (t)->
    bin  = new module.Gram_rule
    rest = new module.Gram_rule
    if t.need_reemerge?
      bin.need_reemerge   = true
      bin.reemerge_parent = t.reemerge_parent # лень фиксить по всему коду
      rest.need_reemerge  = true
      rest.reemerge_parent= t.reemerge_parent
    else
      rest.need_reemerge   = true
      rest.reemerge_parent = t
    
    if t.debug
      bin.debug  = true
      rest.debug = true
    
    bin.is_not_final = true
    bin.sequence  = t.sequence.slice 0, 2
    bin.ret_name = "split_[#{t.signature}]_"+(@split_uid++)
    
    r_seq = t.sequence.slice 2
    refference = 
      name : bin.ret_name
      position : 0
    r_seq.unshift [refference]
    rest.sequence = r_seq
    rest.ret_name = t.ret_name
    rest.signature= t.signature
    
    for k,list of t.hash_ref
      for v in list
        v = clone v
        if v.position <= 1
          bin.hash_ref[k] ?= []
          bin.hash_ref[k].push v
        else
          v.position--
          rest.hash_ref[k] ?= []
          rest.hash_ref[k].push v
    
    for v in t.strict_list
      {bin_rule, rest_rule, bin_pos, rest_pos, add_mx_rule} = @strict_rule_to_bin_rest v, t
      if add_mx_rule?
        bin.mx_hash[add_mx_rule.name] = add_mx_rule
      if bin_rule?
        bin.strict_list.push bin_rule
      if rest_rule?
        rest.strict_list.push rest_rule
    for k,mx_rule of t.mx_hash
      mx_rule = clone mx_rule
      {bin_rule, rest_rule, add_mx_rule} = @strict_rule_to_bin_rest mx_rule.value, t
      if add_mx_rule?
        bin.mx_hash[add_mx_rule.name] = add_mx_rule
      if bin_rule?
        mx_rule.value = bin_rule
        bin.mx_hash[k]  = mx_rule
      if rest_rule?
        mx_rule.value = rest_rule
        rest.mx_hash[k]  = mx_rule
      if bin_rule? and !rest_rule?
        add_mx_rule = new Mx_rule
        add_mx_rule.name  = k
        add_mx_rule.value = strict_rule_parser.parse "$1.#{k}"
        add_mx_rule.value.penetration_flag = bin_rule.penetration_flag if bin_rule.penetration_flag
        rest.mx_hash[k] = add_mx_rule
    
    rest.is_pure = t.is_pure # не уверен
    
    # ret_name  : null       # вродеок
    # signature   : ''         # вродеок
    # sequence  : []         # вродеок
    # mx_hash   : {}         # вродеок
    # strict_list : []         # вродеок
    # is_pure   : false      # не уверен
    # hash_ref  : {}         # вродеок
    
    [bin, rest]
  parse_prepare_binary : ()->
    @split_uid = 0;
    @rule_by_length_list  = []
    @rule_by_length_list[1] = []
    @rule_by_length_list[2] = []
    new_rule_list = []
    for v in @rule_list
      while v.sequence.length > 2
        [bin, v] = @split_rule_left v
        @rule_by_length_list[bin.sequence.length].push bin
        new_rule_list.push bin
      @rule_by_length_list[v.sequence.length].push v
      new_rule_list.push v
    @rule_list = new_rule_list
    
    return
  rule_enumerate : ()->
    for list,length in @rule_by_length_list
      continue if !list
      for rule,k in list
        rule.serialize_length = length
        rule.serialize_uid = k
    return
  token_enumerate : ()->
    for v,k in @merge_history
      v.serialize_uid = k
    for ab_k,list of @token_a_b_list
      for token,k in list
        token.serialize_ab_uid = "ab#{ab_k}[#{k}]"
    
    return
  # ###################################################################################################
  
  merge_history : []
  token_list    : []
  token_a_list  : []
  token_b_list  : []
  token_a_list_new  : []
  token_b_list_new  : []
  token_a_b_list    : {}
  token_a_b_list_new : {}
  pair_table: {}
  # ###################################################################################################
  #  TODO optimize. regular call
  #  try "@rule_by_length_list[2]" in precached variable
  #  try "new flag" instead of separate array
  #  think. too heavy key in pair_table. Maybe use uid's/pointers pair
  #  try new_list_a, new_list_b instead of opt + add if instead dummy prefetch[pos]
  # ###################################################################################################
  stat_merge_pair : 0
  stat_merge_pair_skip : 0
  stat_merge_pair_mix : 0
  stat_merge_pair_mix_hit : 0
  merge_register : (ret, opt={})->
    if ret.b - ret.a > 1
      @token_a_b_list["#{ret.a}_#{ret.b}"] ?= []
      @token_a_b_list["#{ret.a}_#{ret.b}"].push ret
      unless opt.no_new
        @token_a_b_list_new["#{ret.a}_#{ret.b}"] ?= []
        @token_a_b_list_new["#{ret.a}_#{ret.b}"].push ret
    
    @token_a_list[ret.a].push ret
    @token_b_list[ret.b].push ret
    unless opt.no_new
      @token_a_list_new[ret.a].push ret
      @token_b_list_new[ret.b].push ret
    return
  merge_pair : (pos, opt={})->
    a_list = @token_b_list[pos]
    b_list = @token_a_list[pos]
    a_list = opt.new_list_a if opt.new_list_a
    b_list = opt.new_list_b if opt.new_list_b
    
    if a_list.length == 0 or b_list.length == 0
      @stat_merge_pair_skip++
      return false
    @stat_merge_pair++
    is_changed = false
    # ret_arr = []
    
    for rule in @rule_by_length_list[2]
      for v_a in a_list
        for v_b in b_list
          if rule.debug
            code = gram_debug_tracer()
            puts "#{code} rule = '#{rule.signature}' on ['#{v_a.str_uid()}','#{v_b.str_uid()}']"
          ret = rule.check_and_mix [v_a, v_b]
          @stat_merge_pair_mix++
          puts ret if rule.debug
          if ret?
            @merge_history.push ret
            @stat_merge_pair_mix_hit++
            key = "#{pos} #{ret.str_uid()} #{v_a.str_uid()} #{v_b.str_uid()}"
            if @pair_table[key]?
              # puts "conflict"
              # puts "conflict #{key}"
              continue
            @pair_table[key] = true
            
            is_changed = true
            ret.a = v_a.a
            ret.b = v_b.b
            @merge_register ret
            # @token_a_b_list["#{v_a.a}_#{v_b.b}"] ?= []
            # @token_a_b_list_new["#{v_a.a}_#{v_b.b}"] ?= []
            # @token_a_b_list["#{v_a.a}_#{v_b.b}"].push ret
            # @token_a_b_list_new["#{v_a.a}_#{v_b.b}"].push ret
            # # ret_arr.push ret
            # # не уверен
            # @token_a_list[ret.a].push ret
            # @token_b_list[ret.b].push ret
            # @token_a_list_new[ret.a].push ret
            # @token_b_list_new[ret.b].push ret
    
    is_changed
  
  merge_left_to_right : ()->
    puts "merge_left_to_right" if @debug
    is_changed = false
    for i in [1 .. @token_list.length-1]
      opt = new_list_a : @token_b_list_new[i]
      @token_b_list_new[i] = []
      # @token_a_list_new[i] = [] # prevent double mix
      is_changed = true if @merge_pair i, opt
    
    is_changed
  merge_right_to_left : ()->
    puts "merge_right_to_left" if @debug
    is_changed = false
    for i in [@token_list.length-1 .. 1]
      opt = new_list_b : @token_a_list_new[i]
      @token_a_list_new[i] = []
      is_changed = true if @merge_pair i, opt
    
    is_changed
  merge_singles : ()->
    puts "merge_singles" if @debug
    is_changed = false
    for k,list of @token_a_b_list_new
      add_arr = @token_a_b_list[k]
      replaced_new = []
      for v in list
        for rule in @rule_by_length_list[1]
          ret = rule.check_and_mix [v] 
          if ret?
            @merge_history.push ret
            ret.a = v.a
            ret.b = v.b
            is_changed = true
            replaced_new.push ret
            add_arr.push ret
            @token_a_list[ret.a].push ret
            @token_b_list[ret.b].push ret
            @token_a_list_new[ret.a].push ret
            @token_b_list_new[ret.b].push ret
      @token_a_b_list_new[k] = replaced_new
    is_changed
  reemerge : (t)->
    for v in t.value_array
      @reemerge v
    if t.rule? and t.rule.need_reemerge?
      big_node = t.value_array[0]
      
      check = true
      if @fix_overlapping_token
        map = {}
        for v in big_node.value_array
          for i in [v.a ... v.b]
            map[i] = true
        # puts map
        v = t.value_array[1]
        for i in [v.a ... v.b]
          if map[i]?
            check = false
            break
        # puts "fix_overlapping_token!" if !check
      
      big_node.value_array.push t.value_array[1] if check
      t.value_array = big_node.value_array
      t.rule = t.rule.reemerge_parent
    t
  expected_token : null
  has_full : ()->
    return false if @mode_full
    return false if !@token_a_b_list["0_#{@token_list.length}"]?
    if @expected_token?
      found = false
      for v in @token_a_b_list["0_#{@token_list.length}"]
        if v.mx_hash.hash_key == @expected_token
          found = true
          break
      return false if !found
    return true
  parse_list_binary : (list, opt={}) ->
    @pair_table = {}
    @token_a_list = []
    @token_b_list = []
    @token_a_b_list = {}
    @token_a_list_new = []
    @token_b_list_new = []
    @token_a_b_list_new = {}
    @token_list = list
    @merge_history = []
    @expected_token = opt.expected_token
    
    for v,k in list
      if typeof v == 'string'
        n = new Node
        n.mx_hash.hash_key = 'base'
        n.value = v
        # n.value_array = [v] # FIX BUG breaks all stuff see fix at last moment of parse
        n_list = [n]
      else
        n_list = v
        
      for n in n_list # неоптимально т.к. повторы ?= [] , но так читабельнее
        n.a = k
        n.b = k + 1
        @token_a_list[k] ?= []
        @token_a_list[k].push n
        @token_b_list[k+1] ?= []
        @token_b_list[k+1].push n
        @token_a_list_new[k] ?= []
        @token_a_list_new[k].push n
        @token_b_list_new[k+1] ?= []
        @token_b_list_new[k+1].push n
        @token_a_b_list["#{k}_#{k+1}"] ?= []
        @token_a_b_list["#{k}_#{k+1}"].push n
        @token_a_b_list_new["#{k}_#{k+1}"] ?= []
        @token_a_b_list_new["#{k}_#{k+1}"].push n
    if opt.cache_deserialize
      start = new Date
      opt.cache_deserialize @, list
      @stat_ext += ((new Date) - start)/1000
    
    @stat_cycle_counter = 0
    unless @has_full()
      loop
        is_changed = false
        is_changed = true if list.length > 1 and @merge_left_to_right()
        break if @has_full()
        is_changed = true if list.length > 1 and @merge_right_to_left()
        break if @has_full()
        is_changed = true if @merge_singles()
        break if @has_full()
        break if !is_changed
        @stat_cycle_counter++
    if opt.cache_serialize
      start = new Date
      opt.cache_serialize @, list
      @stat_ext += ((new Date) - start)/1000
    emerged = @token_a_b_list["0_#{@token_list.length}"]
    emerged ?= []
    for v,k in emerged
      emerged[k] = @reemerge v
    refined_emerged = []
    for v in emerged
      continue if v.rule?.is_not_final
      continue if opt.expected_token? and v.mx_hash.hash_key != opt.expected_token
      refined_emerged.push v
    for v in refined_emerged # fix base value_array
      if v.mx_hash.hash_key == 'base'
        v.value_array = [new Node v.value]
    refined_emerged
  optimize : ()->
    for v in @rule_list
      v.optimize()
    return
  get_ult_list : (mx_key='ult')->
    res = []
    for v in @rule_list
      if v.mx_hash[mx_key]
        res.push v.mx_hash[mx_key].value.value
    phpjs.array_values phpjs.array_unique res
  debug_look_mx_hash : (t = @token_a_b_list)->
    if t.mx_hash?
      return t.mx_hash.hash_key
    if t instanceof Array
      ret = []
      for v in t
        ret.push @debug_look_mx_hash v
    else
      ret = {}
      for k,v of t
        ret[k] = @debug_look_mx_hash v
      ret
    ret
