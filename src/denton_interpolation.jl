"""
    denton_interpolation(highfreq::AbstractMatrix{<:Real},
                         lowfreq::AbstractVector{<:Real})::Matrix{Float64}

Returns the interpolation using the Proportional Denton Method.
The implementation is taken from the [Quarterly National Accounts Manual – 2017 Edition](https://www.imf.org/external/pubs/ft/qna/) (Chapter 6, pages 121-122).

It assumes no gaps in the series.
"""
function denton_interpolation(highfreq::AbstractMatrix{<:Real}, lowfreq::AbstractVector{<:Real})
    all(iszero, lowfreq) && return zero(highfreq)
    m, n = size(highfreq)
    D = diagm(m * n - 1,
              m * n,
              0 => fill(-1, m * n - 1),
              1 => fill(1, m * n - 1))
    Î = Diagonal(vec(highfreq'))
    M = inv(Î) * (D'D) * inv(Î)
    J = reduce((x, y) -> cat(x, y, dims = (1, 2)), ones(1, n) for i in axes(lowfreq, 1))
    Ω = vcat(hcat(M, J'), hcat(J, zeros(m, m)))
    β = inv(Ω) * vcat((M * vec(highfreq')), lowfreq)
    convert(Matrix{Float64}, reshape(@view(β[1: m * n]), n, m)')
end
