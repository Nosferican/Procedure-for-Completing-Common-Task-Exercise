using CommonTaskExercise, Test
using CommonTaskExercise: XLSX.readxlsx
using DataFrames, Documenter
using Weave: weave

@testset "read_xlsx_sheet" begin
    Section2All_xls = readxlsx(joinpath(dirname(pathof(CommonTaskExercise)),
                                        "..", "data", "Section2All_xls.xlsx"))
    a = read_xlsx_sheet(Section2All_xls, "T20100-A")
    q = read_xlsx_sheet(Section2All_xls, "T20100-Q")
    m = read_xlsx_sheet(Section2All_xls, "T20600-M")
    @test true
end

@testset "denton_interpolation" begin
    # Read the data
    Section2All_xls = readxlsx(joinpath(dirname(pathof(CommonTaskExercise)),
                                        "..", "data", "Section2All_xls.xlsx"))
    a = read_xlsx_sheet(Section2All_xls, "T20100-A")
    q = read_xlsx_sheet(Section2All_xls, "T20100-Q")
    m = read_xlsx_sheet(Section2All_xls, "T20600-M")
    # Tidy the data
    atest = stack(select(a, Not(1:2)), Cols(r"^\d{4}$"), variable_name = :year)
    qtest = stack(select(q, Not(1:2)), Cols(r"^\d{4}Q\d"), variable_name = :Period)
    mtest = stack(select(m, Not(1:2)), Cols(r"^\d{4}M\d{2}"), variable_name = :Period)
    # Clean up the data
    transform!(atest,
               :year => ByRow(x -> parse(Int, x)),
               renamecols = false)
    transform!(qtest,
               :Period => ByRow(x -> parse(Int, SubString(x, 1, 4))) => :year,
               :Period => ByRow(x -> parse(Int, SubString(x, 6, 6))) => :quarter)
    transform!(mtest,
               :Period => ByRow(x -> parse(Int, SubString(x, 1, 4))) => :year,
               :Period => ByRow(x -> (parse(Int, SubString(x, 6, 7)) + 2) ÷ 3) => :quarter,
               :Period => ByRow(x -> parse(Int, SubString(x, 6, 7))) => :month)
    # Interpolate quarterly data based the annual data
    q_a = combine(groupby(qtest, :PublishCd)) do subdf
        a_subdf = subset(atest, :PublishCd => ByRow(isequal(subdf[1, :PublishCd])))
        q_subdf = subset(subdf, :year => ByRow(∈(unique(a_subdf[!,:year]))))
        sort!(q_subdf, [:year, :quarter])
        highfreq = reshape(q_subdf[!,:value], 4, nrow(a_subdf))'
        lowfreq = a_subdf[!,:value]
        interpolation = denton_interpolation(highfreq, lowfreq)
        q_subdf[!,:interpolation] = vec(interpolation')
        q_subdf
    end
    # Interpolate monthly data based the annual data
    m_a = combine(groupby(mtest, :PublishCd)) do subdf
        a_subdf = subset(atest, :PublishCd => ByRow(isequal(subdf[1, :PublishCd])))
        m_subdf = subset(subdf, :year => ByRow(∈(unique(a_subdf[!,:year]))))
        sort!(m_subdf, [:year, :month])
        highfreq = reshape(m_subdf[!,:value], 12, nrow(a_subdf))'
        lowfreq = a_subdf[!,:value]
        interpolation = denton_interpolation(highfreq, lowfreq)
        m_subdf[!,:interpolation] = vec(interpolation')
        m_subdf
    end
    # Interpolate monthly data based the quarterly data
    m_q = combine(groupby(mtest, :PublishCd)) do subdf
        q_subdf = innerjoin(select(qtest, [:PublishCd, :year, :quarter, :value]),
                            unique!(select(subdf, [:year, :quarter, :PublishCd])),
                            on = [:PublishCd, :year, :quarter])
        sort!(q_subdf)
        m_subdf = innerjoin(select(subdf, [:Period, :year, :quarter, :month, :value]),
                            unique!(select(q_subdf, [:year, :quarter])),
                            on = [:year, :quarter])
        sort!(m_subdf, [:year, :month])
        highfreq = reshape(m_subdf[!,:value], 3, nrow(q_subdf))'
        lowfreq = q_subdf[!,:value]
        interpolation = denton_interpolation(highfreq, lowfreq)
        m_subdf[!,:interpolation] = vec(interpolation')
        m_subdf
    end
    # Compute the aggregated version of the interpolation
    qaval = combine(groupby(q_a, [:PublishCd, :year]),
                   :interpolation => sum,
                   renamecols = false)
    maval = combine(groupby(m_a, [:PublishCd, :year]),
                   :interpolation => sum,
                   renamecols = false)
    mqval = combine(groupby(m_q, [:PublishCd, :year, :quarter]),
                    :interpolation => sum,
                    renamecols = false)
    # Verify additive restriction ∋ interpolation very close to the lowfreq values
    qa_val = innerjoin(qaval, atest, on = [:PublishCd, :year])
    @test qa_val[!,:interpolation] ≈ qa_val[!,:value]
    ma_val = innerjoin(maval, atest, on = [:PublishCd, :year])
    @test ma_val[!,:interpolation] ≈ ma_val[!,:value]
    mq_val = innerjoin(mqval, qtest, on = [:PublishCd, :year, :quarter])
    @test mq_val[!,:interpolation] ≈ mq_val[!,:value]
end

DocMeta.setdocmeta!(CommonTaskExercise,
                    :DocTestSetup,
                    :(using CommonTaskExercise),
                    recursive = true)

weave(joinpath(pkgdir(CommonTaskExercise), "docs", "src", "manual.jmd"),
      doctype = "github")

makedocs(sitename = "CommonTaskExercise",
         modules = [CommonTaskExercise],
         source = joinpath(pkgdir(CommonTaskExercise), "docs", "src"),
         build = joinpath(pkgdir(CommonTaskExercise), "docs", "build"),
         pages = [
             "Home" => "index.md",
             "Manual" => "manual.md",
             "API" => "api.md"
         ]
)
