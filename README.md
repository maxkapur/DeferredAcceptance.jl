# DeferredAcceptance

&hellip; is an efficient Julia implementation of a few variations of the deferred acceptance (DA) algorithm, which produce stable, incentive-compatible solutions to school-choice problems.

The author&rsquo;s homepage is [maxkapur.com](https://www.maxkapur.com/).

## Background

In many public school systems, such as those in New York City, Boston, and Amsterdam, students apply for seats by supplying a strict ranking of the schools they would like to attend. Likewise, each school has a ranking of the students, favoring e.g. students who live nearby, have siblings at the school, or have high grades. Schools’ preferences are *not* strict. Each school places students of common favorability into categories and provides a ranking over the categories. In addition, each school has a limit on how many students it can accept, and we assume that schools would prefer any student over an empty seat. Each student may be assigned to at most one school.

The school-choice problem is, given the students’ and schools’ preference lists, what is the best way to assign students to schools? If every student and school has a strict preference list, we can use DA to find a stable assignment (it is often unique). But to address the general case, there are a family of tiebreaking mechanisms that we can use to convert loose preference lists into strict ones.

This module includes my most performant implementation of vanilla DA, and utilities for breaking ties and comparing the assignments that result from various tiebreaking rules.

## Comparison of tiebreaking mechanisms

Here is a cool graph, produced by the script `examples/Hybrid.jl`:

![Simulated market with 170 popular schools, 330 unpopular](plots/hybrid500s500c200n.png)

It compares the cumulative rank distributions associated with various DA tiebreaking rules in a simulated school-choice market involving 120 students and 120 seats. In overdemanded (popular) schools, single tiebreaking (STB) yields both better student welfare and greater equity than multiple tiebreaking (MTB), but MTB produces a more equitable distribution in underdemanded schools. A hybrid tiebreaking rule yields the best of both, but requires clairvoyance about which schools are popular and unpopular, a distinction that is less clear in real-world data (Ashlagi and Afshin, 2020). Thus, a tiebreaking rule of my own creation (convex tiebreaking, XTB), parameterized in &lambda;, allows the market designer to freely modulate the welfare&ndash;equity tradeoff between MTB and STB without prior information about the relative popularity of the schools.

To discover a further extreme of the welfare-equality tradeoff phenomenon in underdemanded markets, we can use the student preference lists as primary tiebreakers; then, any of the four methods above can be used to break the remaining ties. This welfare tiebreaking rule (WTB) reflects the realistic assumption that a given school marginally prefers students who prefer it. WTB dominates STB in overdemanded markets, and in all markets, the difference between WXTB and WHTB (that is, WTB where secondary tiebreaking is performed by XTB or HTB, respectively) vanishes. WSTB is known as the &ldquo;Boston mechanism&rdquo; and is popular among parents even though it is not strategy proof; see Abdulkadiroğlu et al. (2015) for a possible workaround.

Considering the problem from a game-theoretic point of view invites us to compare the stable assignments produced by DA algorithms with the welfare-optimal assignment produced by relaxing the stability constraint. We can compute the latter using integer programming, as well as optimize for total (equivalently, average) welfare subject to stability. Integer programming is instractable for large problems, but here are the results of a single 40-by-40 example, this time where all schools are of equivalent popularity and the market is underdemanded:

![Simulated market with 40 schools, comparing system optima with those produced by DA](plots/sysopt40s40c.png)

The code for this example can be found in the `sysopt/` directory. I used FICO Xpress to solve the integer programs; unfortunately, Xpress is closed source, but the 40-by-40 case is compatible with the limitations imposed by FICO&rsquo;s free community license.

It is not to difficult to show that student-proposing (forward) DA is student optimal&mdash;that is, if both sets of preference orders are strict, student-proposing DA maximizes total student welfare (negative sum of ranks) subject to stability. An area of interest is the welfare cost of using school-proposing (reverse) DA instead. The results of another experiment show that student optimality is protected even when using reverse DA if the WTB tiebreaking mechanism is used; if HTB is used instead, the loss in expected student utility under reverse DA is substantial in underdemanded markets. See `examples/ForwardReverse.jl`.

![Simulated market with 100 schools, comparing results of forward and reverse DA](plots/fwrv100s100c120n.png)

## Two-round dynamic reassignment

Feigenbaum et al. (2020) describe a two-round tiebreaking assignment mechanism that accounts for students who elect to drop out of the lottery (e.g., to attend private school). The implementation challenge here is coming up with realistic input data that reflect the likelihood of students receiving and accepting an outside offer. A sketch appears in the `dynamic/` directory. Making some reasonable assumptions about the extent to which students&rsquo; outside options improve between rounds, I was able to empirically verify their central finding, which is that the second-round assignments dominate the first-round assignments rankwise, and using the reverse lottery numbers in the second round minimizes reassignment and improves equity by moving the students who did worst in the first round many ranks up their preference lists.

![Scatter plot showing rank assignments before and after reassignment in a single 100-by-70 market](plots/dynamic100s70c-scatter.png)

## Nonatomic formulation

Research in this area often uses a nonatomic (continuum) formulation, where the student preferences are represented by a discrete probability distribution over a fixed set of student types, and each school&rsquo;s capacity is some (continuous) number that represents the volume of students it can accept. As the graph below shows, the statistical properties of this model are generally similar to those of discrete DA, but it requires different treatment from a coding standpoint. So far, I have implemented only the student-proposing form in the function `DA_nonatomic()`. See `examples/Nonatomic.jl` for usage.

![Line graph showing cumulative rank distributions in over- and underdemanded nonatomic market](plots/nonatomic30s10c.png)

To my knowledge, the nonatomic formulation of the school-choice problem is due to Azevedo and Leshno (2016).

## A note about performance

The code in this repository is much more performant than the Python code for the Gale-Shapley algorithm that lives [here](https://github.com/maxkapur/assignment), and thus I would recommend using this code to actually generate stable assignments in large problems. A 1000-by-1000 hybrid market like that shown above takes 17 seconds on my unremarkable computer. Overdemanded markets generally take longer than underdemanded markets.

However, the Python code has a few additional features particular to the one-to-one marriage problem that are of independent interest&mdash;namely, it can solve for the optimal stable marriage given an arbitrary linear cost function.

For a discussion of the DA-MTB and DA-STB tiebreaking rules and a few experimental results which I have reproduced in the `plots/` directory, consult Ashlagi and Nikzad (2020).

## References

- Abdulkadiroğlu, Atila, Yeon-Koo Che, Yosuke Yasuda. 2020. &ldquo;Expanding &lsquo;Choice&rsquo; in School Choice.&rdquo; *American Economic Journal: Microeconomics* 7, no. 1 (Feb.): 1&ndash;42.
- Ashlagi, Itai and Afshin Nikzad. 2020. &ldquo;What Matters in School Choice Tie-Breaking? How Competition Guides Design.&rdquo; *Journal of Economic Theory* 190 (Oct.), article no. 105120.
- Azevedo, Eduardo M. and Jacob D. Leshno. 2016. &ldquo;A Supply and Demand Framework for Two-Sided Matching Markets.&rdquo; *Journal of Political Economy* 124, no. 5 (Sept.): 1235&ndash;68.
- Feigenbaum, Itai, Yash Kanoria, Irene Lo, and Jay Sethuraman. 2020. “Dynamic Matching in School Choice: Efficient Seat Reassignment After Late Cancellations.” *Management Science* 66, no. 11 (Nov.) 5341–61.
