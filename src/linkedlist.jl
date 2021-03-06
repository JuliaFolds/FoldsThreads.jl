mutable struct Cons{T}
    car::T
    cdr::Any
end

struct Nil{T} end

const List{T} = Union{Cons{T},Nil{T}}

listof(::Type{T}) where {T} = Nil{T}()
listof(::Type{T}, x::T, xs::T...) where {T} = Cons{T}(x, listof(T, xs...))
Base.empty(::List{T}) where {T} = Nil{T}()

car(x::Cons) = x.car
cdr(x::Cons{T}) where {T} = x.cdr::Union{Cons{T},Nil{T}}

Base.eltype(::Type{List{T}}) where {T} = T
Base.IteratorSize(::Type{<:List}) = Base.SizeUnknown()
Base.iterate(::Nil) = nothing
Base.iterate(lst::Cons{T}, x = lst) where {T} =
    if x isa Cons{T}
        car(x), cdr(x)
    else
        nothing
    end

mutable struct LockedLinkedList{T}
    list::List{T}
    lock::ReentrantLock
    isempty::Threads.Atomic{Bool}
end

LockedLinkedList{T}() where {T} =
    LockedLinkedList{T}(Nil{T}(), ReentrantLock(), Threads.Atomic{Bool}(true))

setlist(l::LockedLinkedList{T}, list::List{T}) where {T} = @set l.list = list

function locked(f, l::LockedLinkedList)
    lock(l.lock) do
        f(l.list)
    end
end

function Base.empty!(l::LockedLinkedList)
    lock(l.lock) do
        l.list = empty(l.list)
        l.isempty[] = true
    end
end

Base.isempty(l::LockedLinkedList) = l.isempty[]

function setcdr!(lst::Cons{T}, cdr::List{T}) where {T}
    lst.cdr = cdr
    return lst
end

function setcdr!(l::LockedLinkedList{T}, cdr::List{T}) where {T}
    lock(l.lock) do
        if l.list isa Nil
            l.list = cdr
            if !(cdr isa Nil)
                l.isempty[] = false
            end
        else
            setcdr!(l.list, cdr)
            l.isempty[] = false
        end
    end
    return
end

function trypopfirst!(l::LockedLinkedList)
    # isempty(l) && return nothing  # TODO: is it OK?
    lock(l.lock) do
        list = l.list
        if list isa Nil
            return nothing
        else
            l.list = newlist = cdr(list)
            if newlist isa Nil
                l.isempty[] = true
            end
            return Some(car(list))
        end
    end
end
