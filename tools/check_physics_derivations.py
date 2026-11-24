#!/usr/bin/env python3
"""Independent small mathematical check for the Replicator handbook.

No measured atomic data and no private project imports. Counts and the
dimensionless focusing-potential threshold ordering are mathematical checks,
not a simulated or measured manufacturing capability.
"""
from fractions import Fraction as F
from itertools import permutations, product
import json
import math
import numpy as np

def cell_vertices():
    phi=(1+math.sqrt(5))/2
    out=[]
    # The standard Cartesian coordinate families of the regular 600-cell.
    out.extend(tuple(s/2 for s in signs) for signs in product((-1,1),repeat=4))
    for axis in range(4):
        for s in (-1,1):
            out.append(tuple(s if j==axis else 0 for j in range(4)))
    base=(0,0.5,phi/2,1/(2*phi))
    for perm in permutations(range(4)):
        inversions=sum(perm[i]>perm[j] for i in range(4) for j in range(i+1,4))
        if inversions%2: continue
        for signs in product((-1,1),repeat=3):
            signed=(0,base[1]*signs[0],base[2]*signs[1],base[3]*signs[2])
            out.append(tuple(signed[j] for j in perm))
    return np.array(out)

V=cell_vertices()
assert len(V) == 120 and len(np.unique(V, axis=0)) == 120
assert np.allclose((V*V).sum(axis=1), 1.0)
d2=((V[:,None]-V[None,:])**2).sum(axis=2)
edge=min(d2[d2>1e-10])
A=np.isclose(d2,edge,atol=1e-10).astype(float)
assert np.all(A.sum(axis=1) == 12)
L=np.diag(A.sum(axis=1))-A
ev=np.linalg.eigvalsh(L)
groups=[]
for value in ev:
    if not groups or abs(value-groups[-1]['eigenvalue'])>1e-7:
        groups.append(dict(eigenvalue=float(value),multiplicity=1))
    else: groups[-1]['multiplicity']+=1

symbols='spdfghijklmno'
states=[(n,l) for n in range(1,13) for l in range(n)]
# The finite enumeration covers all candidates that can enter the first 19:
# for 1<mu<6/5, score increases with l. For n>=8 its minimum is
# (n-1)+1/mu, above score(7p)=5+3/mu by at least 2-2/mu>0.
expected='1s 2s 2p 3s 3p 4s 3d 4p 5s 4d 5p 6s 4f 5d 6p 7s 5f 6d 7p'.split()
def name(state): return str(state[0])+symbols[state[1]]
def score(state,mu):
    n,l=state
    return n-l-1+F(2*l+1,1)/mu
def order(mu):
    return [name(s) for s in sorted(states,key=lambda s:(score(s,mu),s[0],s[1]))[:19]]

index={name(s):s for s in states}
lower,upper=F(0),None
binding=[]
# Every requested state must precede all later requested states and all
# states outside the requested first 19. Exact rational linear inequalities.
for i,label in enumerate(expected):
    a=index[label]
    later=[index[x] for x in expected[i+1:]]+[s for s in states if name(s) not in expected]
    for b in later:
        c=(b[0]-b[1]-1)-(a[0]-a[1]-1)
        d=2*(b[1]-a[1])
        # score_b-score_a = c+d/mu > 0 for positive mu.
        if c>0: lower=max(lower,F(-d,c))
        elif c<0:
            bound=F(-d,c)
            if upper is None or bound<upper: upper=bound
        elif d<=0: raise AssertionError((a,b,c,d))
for a,b in [('6s','4f'),('7s','5f')]:
    binding.append(dict(pair=[a,b],score_at_boundary=str(score(index[a],F(6,5))),equal_at_boundary=score(index[a],F(6,5))==score(index[b],F(6,5))))

out=dict(
    purpose='Exact counting, finite geometry, and threshold-order checks; no empirical validation claimed.',
    method=dict(geometry='Standard regular 600-cell; nearest-neighbor unweighted graph Laplacian', spectral_clustering_tolerance=1e-7, threshold_arithmetic='exact rational inequalities', external_atomic_data=False),
    subshell_capacities=[2*(2*l+1) for l in range(4)],
    principal_shell_capacities=[sum(2*(2*l+1) for l in range(n)) for n in range(1,7)],
    diagonal_capacities=[sum(2*(2*l+1) for l in range((N-1)//2+1)) for N in range(1,9)],
    cell600=dict(vertices=len(V),degrees=sorted(set(map(int,A.sum(axis=1)))),laplacian_multiplicities=[g['multiplicity'] for g in groups],first_six_match_s3=[g['multiplicity'] for g in groups[:6]]==[n*n for n in range(1,7)]),
    threshold_order=dict(analytic_label='lambda=n_r+(2*l+1)/mu; n_r=n-l-1',exact_open_interval=[str(lower),str(upper)],candidate_states=len(states),expected=expected,at_mu_103_over_100=order(F(103,100)),at_mu_1199_over_1000=order(F(1199,1000)),at_mu_1201_over_1000=order(F(1201,1000)),boundary_crossings=binding),
)
assert out['cell600']['first_six_match_s3']
assert (lower,upper)==(F(1),F(6,5))
assert order(F(103,100))==expected
assert order(F(1199,1000))==expected
assert order(F(1201,1000))!=expected
print(json.dumps(out,indent=2))
