#---------------------------------------------------------------# update methods
"""
```
update!(o, data...)
update!(o, data..., b)

update!(o, args...; f::Function)
update!(o, args...; plot::Plots.Plot)
```

Update an OnlineStat with `data...`. If specified, uses minibatches of size `b`.

- If `f` is provided, `f(o)` is called after updating the OnlineStat.
- If `plot` is provided, the plot is updated after the OnlineStat is updated.
"""
function update!(o::OnlineStat, y::Union{AVec, AMat})
    for i in 1:size(y, 1)
        update!(o, row(y, i))
    end
end

function update!(o::OnlineStat, y::Union{AVec, AMat}, b::Integer)
    b = Int(b)
    n = size(y, 1)
    @assert 0 < b <= n "batch size must be positive and less than data size"
    if b == 1
        update!(o, y)
    else
        i = 1
        while i <= n
            rng = i:min(i + b - 1, n)
            updatebatch!(o, rows(y, rng))
            i += b
        end
    end
end

# Statistical Model update
function update!(o::OnlineStat, x::AMat, y::AVec)
    for i in 1:length(y)
        update!(o, row(x, i), y[i])
    end
end

function update!(o::OnlineStat, x::AMat, y::AVec, b::Integer)
    b = Int(b)
    n = length(y)
    @assert 0 < b <=n "batch size must be positive and less than data size"
    if b == 1
        update!(o, x, y)
    else
        i = 1
        while i <= n
            rng = i:min(i + b - 1, n)
            updatebatch!(o, rows(x, rng), rows(y, rng))
            i += b
        end
    end
end

# If an OnlineStat doesn't have an updatebatch method, just use update
updatebatch!(o::OnlineStat, data...) = update!(o, data...)


############# With keyword arguments
# Thanks to multiple dispatch and above definitions, these methods can only be called
# by specifying the keyword argument
function update!(o::OnlineStat, args...; f::Function = o->state(o)[1])
    update!(o, args...)
    f(o)
end

function update!(o::OnlineStat, args...; plot::Plots.Plot = Plots.plot([0]), kw...)
    update!(o, args...)
    # make sure state(o)[1] is Vector
    push!(plot, nobs(o), vcat(state(o)[1]); kw...)
end



#------------------------------------------------------------------------# Other
"The number of observations"
StatsBase.nobs(o::OnlineStat) = o.n

Base.copy(o::OnlineStat) = deepcopy(o)

function Base.merge(o1::OnlineStat, o2::OnlineStat)
    o1copy = copy(o1)
    merge!(o1copy, o2)
    o1copy
end

function Base.(:(==)){T<:OnlineStat}(o1::T, o2::T)
    @compat for field in fieldnames(o1)
        getfield(o1, field) == getfield(o2, field) || return false
    end
    true
end


row(x::AMat, i::Integer) = rowvec_view(x, i)
col(x::AMat, i::Integer) = view(x, :, i)
row!{T}(x::AMat{T}, i::Integer, v::AVec{T}) = (x[i,:] = v)
col!{T}(x::AMat{T}, i::Integer, v::AVec{T}) = (x[:,i] = v)
row(x::AVec, i::Integer) = x[i]

rows(x::AVec, rs::AVec{Int}) = view(x, rs)
rows(x::AMat, rs::AVec{Int}) = view(x, rs, :)
cols(x::AMat, cs::AVec{Int}) = view(x, :, cs)

rows(x::AbstractArray, i::Integer) = row(x,i)
cols(x::AbstractArray, i::Integer) = col(x,i)

nrows(M::AbstractArray) = size(M,1)
ncols(M::AbstractArray) = size(M,2)


#------------------------------------------------------------------------# Show

# TODO: use my "fmt" method in Formatting.jl if/when the PR is merged
# temporary fix for the "how to print" problem... lets come up with something nicer
mystring(f::AbstractFloat) = @sprintf("%f", f)
mystring(x) = string(x)


name(o::OnlineStat) = string(typeof(o))


function Base.print{T<:OnlineStat}(io::IO, v::AVec{T})
    print(io, "[")
    print(io, join(v, ", "))
    print(io, "]")
end

function Base.print(io::IO, o::OnlineStat)
    snames = statenames(o)
    svals = state(o)
    print(io, name(o), "{")
    for (i,sname) in enumerate(snames)
        print(io, i > 1 ? " " : "", sname, "=", svals[i])
    end
    print(io, "}")
end

function Base.show(io::IO, o::OnlineStat)
    snames = statenames(o)
    svals = state(o)
    print(io, "OnlineStat: ", name(o))
    for (i, sname) in enumerate(snames)
        print(io, @sprintf("\n > %8s:  %s", sname, mystring(svals[i])))
    end
end
