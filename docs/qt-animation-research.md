# Lightweight Qt motion for Prismarine

Researched 2026-11-05 against Qt's official documentation and Prismarine's current
QML. The choices below are design recommendations, not measured performance
guarantees. Native Qt Quick types already cover the proposed effects; a new
animation dependency is unnecessary for this scope.

## Recommended vocabulary

| Visual behavior | Existing Qt mechanism | Suggested use in Prismarine |
| --- | --- | --- |
| Short fade plus a small directional slide | `Transition`, `ParallelAnimation`, `NumberAnimation`, easing | Refine `MotionLoader`: approximately 160–220 ms and 8–16 logical pixels. Make back navigation reverse direction. |
| A selection indicator glides between targets | `SmoothedAnimation`, or a view's built-in highlight movement | Rail selection and controller focus: retarget smoothly during rapid input, while actual focus moves immediately. |
| A restrained spring on selection or release | `SpringAnimation` | Optional small-scale feedback on selected cards or a primary action. Use damping and an appropriate settling epsilon; avoid continuous wobbling. |
| Cards make room for an inserted/removed item | `ListView` / `GridView` `add`, `remove`, `move`, `displaced` transitions | Library/content changes. Start with a short fade/slide rather than replaying an entrance for the entire library. |
| Dialogs and menus settle into place | Existing enter/exit `Transition` and grouped opacity/scale animation | Refine `MotionDialog` and menus; roughly 140–200 ms, with only a small scale change. |
| Clear button press/release feedback | `Behavior`, `NumberAnimation`, `ColorAnimation` | Keep `ActionButton`/`NavButton`; standardize timing and focus feedback instead of replacing their implementation. |

Qt provides the basic transition, behavior, grouping, and specialized animation
types directly. Specialized number/color/rotation animations are preferable to
generic `PropertyAnimation` for their matching value types.
[Qt animation overview](https://doc.qt.io/qt-6/qtquick-statesanimations-animations.html)

`SmoothedAnimation` maintains velocity when a target changes, which makes it a
good candidate for repeated D-pad movements. A `ListView` also has built-in
highlight movement controls, so a custom interpolation loop is unnecessary.
[SmoothedAnimation](https://doc.qt.io/qt-6/qml-qtquick-smoothedanimation.html),
[ListView highlights](https://doc.qt.io/qt-6/qml-qtquick-listview.html#highlightMoveDuration-prop)

`SpringAnimation` supplies the spring behavior and a settling tolerance. The
small, restrained use above is a design choice; it still needs measurement and
reduced-motion handling.
[SpringAnimation](https://doc.qt.io/qt-6/qml-qtquick-springanimation.html)

View transitions already handle item insertion, removal, movement, and displacement.
However, Prismarine currently resets its instance model in filtering/reloading.
We must match transitions to real model notifications; merely adding a `move`
animation will not turn a model reset into an incremental move.
[ViewTransition](https://doc.qt.io/qt-6/qml-qtquick-viewtransition.html),
[current model](../src/core/library/instancemodel.cpp)

`StackView` has built-in push/pop/replace transition hooks if navigation eventually
needs stack-owned page lifetimes. The existing `NavigationHistory`/`MotionLoader`
can support the initial polish; adopting a new navigation container is a separate
architecture decision, not a requirement for better motion.
[StackView](https://doc.qt.io/qt-6/qml-qtquick-controls-stackview.html)

## Animator types are conditional candidates

`OpacityAnimator`, `ScaleAnimator`, `XAnimator`, and `YAnimator` update scene-graph
state and can run on the rendering thread. Their QML property values update only
after completion, so they are unsuitable where hit testing, focus positioning,
or other bindings need to track intermediate values. Pure Animator groups can
retain render-thread execution; mixing in ordinary animations changes that.
Qt explicitly documents no benefit on a non-threaded render loop.
[Animator documentation](https://doc.qt.io/qt-6/qml-qtquick-animator.html)

The baseline on this Gentoo/Wayland/NVIDIA setup reported the **basic** render
loop. Consequently, replacing every `NumberAnimation` with an Animator would not
establish an improvement here. Keep both backend behavior and correctness in the
comparison. These Animator types also appear in Qt 6.5 documentation; no Qt 6.12
upgrade is proposed.
[Qt 6.5 Animator documentation](https://doc.qt.io/qt-6.5/qml-qtquick-animator.html)

## Performance and accessibility rules

Animate a small number of visible properties. Prefer visual transforms over
repeated layout changes when the effect permits it. Avoid per-frame JavaScript
and unnecessary reevaluation of dependent bindings. Explicitly stop ongoing work
when its indicator is inactive or its window is hidden. Qt documents that hidden
objects can retain active animations and bindings.
[Qt Quick performance guidance](https://doc.qt.io/qt-6/qtquick-performance.html#animations)

For richer artwork, reuse the existing `MultiEffect` selectively. Qt identifies
blur/shadow as its heaviest effects, recommends small source surfaces, and warns
against animating properties that change shader variants or effect dimensions.
A fading border or selection fill is a better initial focus treatment than a
blurred glow on every library card.
[MultiEffect performance](https://doc.qt.io/qt-6/qml-qtquick-effects-multieffect.html#performance)

Reduced motion should snap to the correct final state without moving focus late
or delaying input. Selection feedback must work through keyboard/controller focus
as well as hover. Timing and distance suggestions above are starting points for
review, not mandatory values from Qt.

## First concrete work to review

1. Fix inactive motion before adding effects: the baseline found a running
   `NavigationRail` animation under an invisible indicator, with continuous idle
   rendering. Disabling animations removed continuous idle frames in a diagnostic
   run; see [the baseline](baseline-2026-11-05.md).
2. Establish shared timing/easing choices around existing motion components.
3. Prototype a retargetable selection indicator and shorter page/dialog motion.
4. Compare behavior with rapid input, reduced motion, hidden windows, and both
   small/large libraries before broad adoption.

Qt's [official animation examples](https://doc.qt.io/qt-6/qtquick-animation-example.html)
provide small working examples of the primitives above, suitable for studying
and adapting within their applicable source licenses.
