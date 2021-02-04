# This is not the usual style of trampoline (thunk-returning functions) and
# maybe there's a better name (pop-call-append?). We do not transform the
# recursion fully to a loop for work-stealing scheduler. Until the first
# base case (initial decent), the recursion is used as usual (so still consumes
# O(log2 n) stack space). The required amount of stack space is comparable to
# other divide-and-conquer implementations. The idea/assumption is that it
# _might_ be a good idea to keep the recursion so that the compiler can infer
# types in many cases (TODO: check this). Once the call stack is constructed by
# the recursion, the continuations in the chain (cactus stack) are evaluated in
# a loop ("trampoline"). That said, it'd be interesting to see if the standard
# trampoline has some performance/implementation advantages.

and_finally(@nospecialize f) = listof(Function, f)

before(@nospecialize(f), chain::List{Function}) = Cons{Function}(f, chain)

function trampoline_fallback(chain, x)
    chain isa Nil && return x
    while true
        f = car(chain)
        y = f(x)
        if y === nothing
            return
        elseif y isa Some
            x = something(y)
            chain2 = cdr(chain)
            chain2 isa Nil && return
            chain = chain2
        elseif y isa Tuple{Cons{Function},Any}
            chain, x = y
        else
            unexpected(y)
        end
    end
end

@noinline unexpected(x) = error("unexpected type: $x")

"""
Semantically equivalent to `trampoline_fallback` but tries to type-stabilize.
"""
function trampoline(chain, x)
    chain isa Nil && return x
    # return trampoline_fallback(chain, x)
    trampoline_stabilizing(chain, x, typeof(car(chain)), typeof(x))
end

@generated function trampoline_stabilizing(chain, x, ::Type{TF}, ::Type{TX}) where {TF,TX}
    function unwrap_types(@nospecialize T)
        types = Any[]
        while true
            if T isa Union
                push!(types, T.a)
                T = T.b
            else
                push!(types, T)
                break
            end
        end
        return types
    end
    ftypes = unwrap_types(TF)
    xtypes = unwrap_types(TX)

    if any(!Base.isconcretetype, ftypes) || any(!Base.isconcretetype, xtypes)
        # tuple of union? falling back...
        return :(trampoline_fallback(chain, x))
    end
    if length(ftypes) * length(xtypes) > 16
        return :(trampoline_fallback(chain, x))
    end

    recurse = quote
        return trampoline_stabilizing(chain, x, Union{typeof(f),TF}, Union{typeof(x),TX})
    end

    fbranches = foldr(ftypes, init = recurse) do ft, ex
        quote
            if f isa $ft
                y = f(x)
            else
                $ex
            end
        end
    end
    xbranches = foldr(xtypes, init = recurse) do xt, ex
        quote
            if x isa $xt
                $fbranches
            else
                $ex
            end
        end
    end

    quote
        chain isa Nil && return x
        while true
            f = car(chain)
            $xbranches  # y = f(x)
            if y === nothing
                return
            elseif y isa Some
                x = something(y)
                chain2 = cdr(chain)
                chain2 isa Nil && return
                chain = chain2
            elseif y isa Tuple{Cons{Function},Any}
                chain, x = y
            else
                unexpected(y)
            end
        end
    end
end
