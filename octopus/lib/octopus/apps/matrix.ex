defmodule Octopus.Apps.Matrix do
  use Octopus.App, category: :animation

  defmodule Particle do
    defstruct [:x, :y, :z, :speed, :color, :age, :max_age, :tail]

    # Returns an rgb tuple for the particle dependent on its age and max_age
    # The color is a shade of green
    def color(%Particle{age: age, max_age: max_age, x: x, y: y, z: z, color: {r, g, b}}, factors) do
      # factor = Map.get(factors, {trunc(x), trunc(y)}, 1 - age / max_age)
      # {trunc(r * factor) |> max(0), trunc(g * factor) |> max(0), trunc(b * factor) |> max(0)}
      {trunc(r * z) |> max(0), trunc(g * z) |> max(0), trunc(b * z) |> max(0)}
    end
  end

  defmodule State do
    alias Octopus.Canvas

    defstruct [:canvas, :particles, :factors]

    def spawn_particles(%State{particles: particles} = state, amount) do
      new_particles =
        Enum.map(1..amount, fn _ ->
          %Particle{
            x: :rand.uniform(80),
            y: :rand.uniform(8) - 12,
            z: :rand.uniform() * 0.5 + 0.5,
            speed: 6.0 + :rand.uniform() * 10.0,
            age: 0.0,
            max_age: 3 + :rand.uniform() * 3,
            tail:
              Enum.map(1..(4 + :rand.uniform(3)), fn _ ->
                Enum.random([{:rand.uniform(20), 160 + :rand.uniform(55), :rand.uniform(20)}])
              end),
            color: {:rand.uniform(40), 200 + :rand.uniform(55), :rand.uniform(40)}
          }
        end)

      %State{state | particles: particles ++ new_particles}
    end

    def update(state, dt) do
      particles =
        state.particles
        |> Enum.map(fn %Particle{x: x, y: y, speed: speed, age: age} = particle ->
          %Particle{
            particle
            | x: x,
              y: y + speed * dt,
              speed: speed,
              age: age + dt
          }
        end)
        |> Enum.filter(fn %Particle{y: y, age: age, max_age: max_age} ->
          y < 16 and age < max_age
        end)

      %State{state | particles: particles}
    end

    def render(%State{canvas: _canvas, particles: particles, factors: factors} = state) do
      canvas = Canvas.new(80, 8)

      canvas =
        particles
        |> Enum.sort_by(fn %Particle{z: z} -> z end)
        |> Enum.reduce(canvas, fn %Particle{x: x, y: y, age: age} = particle, canvas ->
          canvas =
            particle.tail
            |> Enum.with_index()
            |> Enum.reduce(canvas, fn {color, i}, canvas ->
              Canvas.put_pixel(canvas, {x, y - (i + 1)}, color)
            end)

          Canvas.put_pixel(canvas, {trunc(x), trunc(y)}, {150, 255, 150})
        end)

      %State{state | canvas: canvas}
    end
  end

  alias Octopus.Canvas

  def name(), do: "Matrix"

  def init(_config) do
    canvas = Canvas.new(80, 8)
    particles = []
    :timer.send_interval(trunc(1000 / 60), :tick)
    :timer.send_interval(50, :spawn_particles)
    :timer.send_interval(1000, :change_factors)
    send(self(), :change_factors)
    {:ok, %State{canvas: canvas, particles: particles, factors: %{}}}
  end

  def handle_info(:spawn_particles, %State{} = state) do
    state =
      if Enum.count(state.particles) < 200 do
        State.spawn_particles(state, 1)
      else
        state
      end

    {:noreply, state}
  end

  def handle_info(:tick, %State{} = state) do
    state = state |> State.update(1 / 60) |> State.render()
    state.canvas |> Canvas.to_frame() |> send_frame()
    {:noreply, state}
  end

  def handle_info(:change_factors, %State{} = state) do
    factors =
      Enum.map(0..32, fn _ ->
        {{:rand.uniform(79), :rand.uniform(7)}, :rand.uniform() * 0.2 + 0.8}
      end)
      |> Enum.into(%{})

    {:noreply, %State{state | factors: factors}}
  end
end
