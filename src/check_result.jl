# For once you have the sensitivity by two methods (e.g  both finite-differencing and  AD)
# the code here checks it is correct.
# Goal is to only call `@isapprox` on things that render well
# Note that this must work well both on Differnetial types and Primal types

"""
    _check_equal(actual, expected; kwargs...)

`@test`'s  that `actual ≈ expected`, but breaks up data such that human readable results
are shown on failures.
All keyword arguments are passed to `isapprox`.
"""
function _check_equal(
    actual::Union{AbstractArray{<:Number}, Number},
    expected::Union{AbstractArray{<:Number}, Number};
    kwargs...
)
    @test isapprox(actual, expected; kwargs...)
end

for (T1, T2) in ((AbstractThunk, Any), (AbstractThunk, AbstractThunk), (Any, AbstractThunk))
    @eval function _check_equal(actual::$T1, expected::$T2; kwargs...)
        _check_equal(unthunk(actual), unthunk(expected); kwargs...)
    end
end

function _check_equal(actual::Union{Composite, AbstractArray}, expected; kwargs...)
    if actual == expected  # if equal then we don't need to be smarter
        @test true
    else
        @test length(actual) == length(expected)
        @testset "$ii" for ii in keys(actual)  # keys works on all Composites
            _check_equal(actual[ii], expected[ii]; kwargs...)
        end
    end
end

_check_equal(::AbstractZero, x; kwargs...) = _check_equal(zero(x), x; kwargs...)
_check_equal(x, ::AbstractZero; kwargs...) = _check_equal(x, zero(x); kwargs...)
_check_equal(x::AbstractZero, y::AbstractZero; kwargs...) = @test x === y

# Generic fallback, probably a tuple or something
function _check_equal(actual::A, expected::E; kwargs...) where {A, E}
    if actual == expected  # if equal then we don't need to be smarter
        @test true
    else
        c_actual = collect(actual)
        c_expected = collect(expected)
        if (c_actual isa A) && (c_expected isa E)  # prevent stack-overflow
            throw(MethodError, _check_equal, (actual, expected))
        end
        _check_equal(c_actual, c_expected; kwargs...)
    end
end

"""
_check_add!!_behavour(acc, val)

This checks that `acc + val` is the same as `add!!(acc, val)`.
It matters primarily for types that overload `add!!` such as `InplaceableThunk`s.

`acc` is the value that has been accumulated so far.
`val` is a deriviative, being accumulated into `acc`.

`kwargs` are all passed on to isapprox
"""
function _check_add!!_behavour(acc, val; kwargs...)
    # Note, we don't test that `acc` is actually mutated because it doesn't have to be
    # e.g. if it is immutable. We do test the `add!!` return value.
    # That is what people should rely on. The mutation is just to save allocations.
    acc_mutated = deepcopy(acc)  # prevent this test changing others
    _check_equal(add!!(acc_mutated, val), acc + val; kwargs...)
end
