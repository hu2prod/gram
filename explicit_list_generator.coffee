require 'fy'
class Explicit_list_generator
  gen_explicit_list_reverse : (list_of_list, pos = 0)->
    if pos == list_of_list.length-1
      list = list_of_list.last()
      return ([v] for v in list)
    else
      ret = []
      bind = @gen_explicit_list_reverse(list_of_list, pos+1)
      for bind_v in bind
        for v in list_of_list[pos]
          c_bind_v = clone bind_v
          c_bind_v.push v
          ret.push c_bind_v
      return ret
  gen : (list_of_list)->
    rev_list = @gen_explicit_list_reverse list_of_list
    for v,k in rev_list
      rev_list[k] = v.reverse()
    
    rev_list
@explicit_list_generator = new Explicit_list_generator
