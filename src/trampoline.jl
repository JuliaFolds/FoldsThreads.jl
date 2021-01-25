and_finally(@nospecialize f) = listof(Function, f)

before(@nospecialize(f), chain::List{Function}) = Cons{Function}(f, chain)

function trampoline(chain, x)
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
        elseif y isa Tuple{List{Function},Any}
            chain, thunk = y
            x = thunk()
        else
            unexpected(y)
        end
    end
end

@noinline unexpected(x) = error("unexpected type: $x")
