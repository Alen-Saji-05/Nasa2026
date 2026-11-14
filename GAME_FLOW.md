# Dust Storm Dispatch: Game Flow (simple version)

Read this top to bottom. It is the story of one game, in the order things happen. Each part says what the player does, what the game does, and WHY (the cause).

Status: Part 1 (walking, camera) is DONE. Do the parts in order.
Facts marked (verify) need checking before you use them in the submission.

## The goal
Stay alive on Mars, survive a dust storm, build a rocket, and launch home.

## The 4 things that can kill you
1. No oxygen (O2).
2. No water.
3. The base gets too cold and breaks.
4. Time runs out (the return window closes on day 30).
Everything in the game connects back to these four.

## Words used in the game
- Sol: a day on Mars. In our game 1 sol = 15 real seconds.
- Power: energy for the base. It runs the heater and the oxygen machine.
- Dust storm: dust in the air blocks sunlight, so solar panels make almost no power.

---

## PART 1: Walk around (DONE)
- Player does: moves with WASD. Camera follows.
- Game does: nothing else yet.

## PART 2: The map has edges
- Player does: tries to walk off the map.
- Game does: invisible walls stop them.
- Why: keeps the game small and the player near the base.

## PART 3: Collect metal
- Player does: walks to a rock with metal and presses E.
- Game does: metal goes up by 8. Oxygen goes down by 1. The rock has 5 uses, then looks empty.
- Why: metal is needed to build everything. Going outside uses suit oxygen.
- Cannot collect when: the rock is empty, or oxygen is almost zero (message: "Not enough oxygen to go outside").

## PART 4: Collect ice (water)
- Player does: same as metal, at an ice node.
- Game does: water goes up by 6. Oxygen down by 1. 5 uses per node.
- Why: people need water, and the oxygen machine uses water. Ice is the water source on Mars.
- Real link: there is water ice on Mars (verify details).

## PART 5: Life drains over time
- Player does: nothing. Time passes.
- Game does: oxygen and water go down slowly all the time.
- Why: the astronaut breathes and drinks every day. This is the pressure that forces the player to act.
- Warnings: numbers blink red when low.

## PART 6: Day and night
- Game does: each sol has day and night. At night the screen gets darker.
- Why: Mars rotates like Earth. A sol is about 24 hours and 37 minutes (verify).
- Effect: solar panels only work by day.

## PART 7: Build machines (the main activity)
- Player does: walks to an empty build square and presses E. A menu opens. Picks a machine.
- Game does: if you have enough metal, the machine appears and metal is spent.
- Cannot build when: not enough metal or water (message: "Not enough resources").
- Machines:
  1. Solar panel: makes power from sunlight.
  2. Battery: stores power for the night.
  3. Oxygen generator: makes oxygen using power and water.
  4. Backup power: makes power all the time, even in a storm.
  5. Ascent vehicle (rocket): only on the launch pad square. This is how you win.
- Real link: Perseverance carried an experiment (MOXIE) that made oxygen from Mars air (verify). Curiosity and Perseverance use radioisotope power that works without sunlight (verify).

## PART 8: Power
- Game does every moment:
  - Power made = solar panels (only in daylight, reduced by dust) + backup power.
  - Power used = heater + oxygen generator (when running).
  - Extra power fills the battery. Missing power drains the battery.
- Cause and effect:
  - More panels = more power by day.
  - Battery = survive the night.
  - Battery empty and not enough power = heater and oxygen machine slow down or stop.

## PART 9: Cold
- Game does: Mars is very cold (about -55 C on average in our game). The heater keeps the base at 20 C.
- If power runs short: heater weakens. The base temperature drops toward the outside.
- If the base goes below 0 C: the base slowly takes damage.
- If damage reaches the limit: you lose ("Habitat froze").

## PART 10: Oxygen generator at work
- Game does: if you built one and oxygen is below 95, it runs by itself. It uses power and a little water. It adds oxygen.
- Why: starting oxygen only lasts about 16 sols. Without a generator you will run out.
- If no power or no water: it stops. Oxygen falls again.

## PART 11: Warning before the storm
- Game does: a text on screen says "Dust in 2 sols: LOW, MEDIUM, or HIGH". The radio may also say "Dust opacity rising".
- Why: real orbiters watch Mars weather and warn rovers (verify). It gives the player time to prepare.
- Good player does: builds backup power now.

## PART 12: The dust storm (days 10 to 18)
- Game does: the sky turns orange. Solar panels make almost nothing for about 8 days. The weather data (generated, shaped like a real global storm) drives this.
- Why: dust in the air blocks sunlight.
- Real link: in 2018 a global dust storm covered Mars and the Opportunity rover lost contact and its mission ended (verify). InSight's solar panels also got covered in dust (verify).

## PART 13: What happens in a storm (the chain)
Without backup power:
1. Dust blocks the sun, so solar power is almost zero.
2. The battery drains.
3. The heater and oxygen generator slow down or stop.
4. The base gets cold.
5. Oxygen starts dropping.
6. The base freezes or oxygen runs out, so you LOSE.
With backup power:
1. Backup power keeps making power.
2. The heater and oxygen generator keep running.
3. You survive. The lesson: missions need power that does not depend on the sun.

## PART 14: After the storm
- Game does: sky clears, solar works again. Message: "Skies clearing."
- Player does: collects more metal and prepares the rocket.

## PART 15: Build the rocket
- Player does: goes to the launch pad square, presses E, picks "Ascent vehicle".
- Cost: 80 metal and 40 water.
- Cannot build when: not enough metal or water.
- Real link: bringing astronauts home from Mars needs a vehicle that launches from the surface (verify).

## PART 16: Launch and win
- Game does: "Ignition in 3 seconds", then the win screen.
- End screen shows: what you built and 3 real NASA facts.

## PART 17: All the ways to lose
| Cause | Result | Message |
|---|---|---|
| Oxygen at zero for 6 seconds | Lose | Out of oxygen |
| Water at zero for 6 seconds | Lose | Out of water |
| Base too cold for too long | Lose | Habitat froze |
| Day 30 passes | Lose | Return window closed |

## PART 18: End screen and restart
- Player does: reads the result and presses Restart.
- Game does: everything resets and the start screen appears again.

---

## A good run, day by day (so you know what a player should do)
- Sols 1 to 4: collect metal and ice near the base.
- Sols 4 to 8: build 1 or 2 more solar panels and a battery.
- Sols 7 to 9: build the oxygen generator.
- Sols 8 to 10: build backup power. This is the key move.
- Sols 10 to 18: storm. Stay near the base, keep collecting ice if water is low.
- Sols 18 to 25: gather metal, build the rocket, launch.

## Order to build the game (use this as your to-do list)
1. DONE: walk and camera (Part 1)
2. Map edges (Part 2)
3. Collect metal, then ice (Parts 3, 4)
4. Oxygen and water drain, plus the numbers on screen (Part 5)
5. Day and night clock (Part 6)
6. Build squares and menu (Part 7)
7. Power and battery (Part 8)
8. Cold and base damage (Part 9)
9. Oxygen generator (Part 10)
10. Weather: storm, dust tint, solar drop, forecast text (Parts 11, 12)
11. Backup power (Part 13)
12. Rocket, launch, win (Parts 15, 16)
13. Lose rules and restart (Parts 17, 18)
14. Start screen, end screen with NASA facts
15. Real art, testing, README, demo video

If you run short of time, finish steps 2 to 13 first. Drop the rest.

## Checks (play it once and ask)
- Does the player always know what to do next?
- Does every number change for a reason you can explain?
- Can a new player survive the storm if they plan well, and fail if they do not?
