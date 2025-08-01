module TablesExt

using AccessibleModels
using AccessibleModels: @p, flatmap
using Tables

Tables.istable(::Type{<:AccessibleModel}) = true
Tables.columnaccess(::Type{<:AccessibleModel}) = true
function Tables.columns(m::AccessibleModel)
    rows = flatmap(zip(m.optics, m.distributions)) do (o, prior)
        curvals = getall(m.modelobj, o)

        labels = @p let
            AccessorsExtra.flat_concatoptic(m.modelobj, o)
            AccessorsExtra._optics
            map(AccessorsExtra.barebones_string)
        end

        map(enumerate(labels)) do (j, label)
            (;
                param=label,
                value=curvals[j],
                prior=string(prior),
            )
        end
	end
    cols = columntable(rows)
    map(col -> collect(promote(col...)), cols)
end


function AccessibleModels.from_table(tbl, m::AccessibleModel)
    param_to_val = @p let
        rowtable(tbl)
        map() do r
            r.param => r.value
        end
        Dict
    end
    param_names = flatmap(m.optics) do o
        @p let
            AccessorsExtra.flat_concatoptic(m.modelobj, o)
            AccessorsExtra._optics
            map(AccessorsExtra.barebones_string)
        end
    end
    raw_vec = map(param_names) do name
        param_to_val[name]
    end
    return AccessibleModels.from_raw(raw_vec, m)
end

end
