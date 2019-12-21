module generators;
import std.traits;

public:
/++
    Generate an array of n randomly generateds T's in 
    the closed interval [a, b]. Emphasis on random, to avoid
    compiler optimizations corrupting benchmark results.
+/
@safe T[] uniformArray(T)(ulong n, T a, T b)
    if(isNumeric!T)
    out(o; o.length == n)
{
    auto tmp = new T[x];
    foreach (ref i; tmp)
    {
        import std.random;
        i = uniform(a, b);
    }
    return tmp;
}

///
@safe unittest {
    //Pass it to parameterizer by aliasing with your a, b

    alias generate(n) = (n) => uniformArray(n, -20, 20);

}
/++
    Generate n numbers distributed N(mu, sigma^2)
+/
F[] normalFloats(F)(ulong n, F mu, F sigma)
    if(isFloatingPoint!F)
    out(o; o.length == n)
{
    import std.mathspecial;
    auto tmp = new F[x];
    foreach (ref i; tmp)
    {
        import std.random;
        const uni = uniform(F(0), F(1));
        const normal = normalDistribution(uni);
        i = normal * sigma + mu;
    }
    return tmp;
}
///
@safe unittest 
{
    const y = normalFloats!float(200, 3.14159, 1);
    float tmp = 0;

    foreach(g; y)
        tmp += g;
    writeln(tmp / g);
}
/++
    Generate data in order in [min, max$(RPAREN) (in "steps").
    Reason: Being nice to the branch predictor (A/B testing).
                    
+/
T[] inorderDataArray(T)(ulong n, T min, T max, T step)
    out(o; o.length == n)
{
    import std.range : iota, array;
    return iota(min, max, step).array;
}