# swift-spring

Use this package when something should move like a mass on a damped spring and you need its position at an instant without simulating the instants before it. Start from `Spring<Scalar>`, built from mass, stiffness and damping or from a natural frequency and a damping ratio, and ask for `state(at:from:)`: the displacement from rest and the velocity at any time, from any initial displacement and velocity. Because the answer is a formula in the time, frames can be computed alone, out of order and in parallel, and always agree. The scalar supplies `exp`, `log`, `sin` and `cos` through `Exponential.Protocol` and `Trigonometry.Circular`; this package conforms no type.

## Laws

- A spring has finite mass and stiffness above zero and finite damping of zero or more. Construction fails with `.mass`, `.stiffness` or `.damping`, checked in that order. `Spring(frequency:ratio:)` is the spring of unit mass with stiffness `frequency²` and damping `2 × ratio × frequency`; it fails with `.stiffness` for a frequency that is not positive and finite or whose square is not finite, and with `.damping` for a ratio that is negative or not finite.
- `frequency` is the natural angular frequency √(stiffness / mass), in radians per unit of time. `ratio` is damping / (2 √(stiffness × mass)). `regime` compares damping² with 4 × mass × stiffness exactly, with no tolerance: `.under` when smaller (this includes no damping at all), `.critical` when equal, `.over` when larger.
- `state(at:from:)` is the exact solution of mass × x″ + damping × x′ + stiffness × x = 0 with x(0) and x′(0) taken from the initial state, one formula per regime. Displacement is measured from rest, so every damped spring tends to zero. The default initial state is `.released`: displaced by one, not moving. `displacement(at:from:)` and `velocity(at:from:)` are its two parts.
- At time zero the state is the initial state, exactly. Any other time, negative ones included, is put into the formula as it is.
- The state after t + s equals the state after s started from the state after t, up to rounding. This is what makes a frame computable on its own.
- An undamped spring released from one is cos(frequency × t). A critically damped spring released from one decreases at every moment and never crosses zero. An underdamped one crosses zero.
- `energy(of:)` is (mass × velocity² + stiffness × displacement²) / 2. Along the motion it never grows, and without damping it stays the same.
- Close to a damping ratio of one the under- and overdamped formulas divide by a small number; they still agree with the critical formula to about the distance of the ratio from one.
- `settling(within:from:)` is a time from which the displacement stays within the tolerance for good. It is a bound from the motion's envelope, not the earliest such time. It is zero when the envelope starts within the tolerance, and `nil` for an undamped spring that moves beyond the tolerance, which never settles. A tolerance that is not positive traps.
- Results are as repeatable across platforms as the scalar's `exp`, `log`, `sin` and `cos`.
