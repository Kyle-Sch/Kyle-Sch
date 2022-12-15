consoles = ["playstation", "xbox", "nintendo"]
for console in consoles:
    print(console)
print("loop over")

for value in range(1, 6):
    print(value)

numbers = list(range(1, 6))
print(numbers)

even_numbers = list(range(1, 6, 2))
print(numbers)

players = ["kyle", "mike", "corey"]
for player in players[:2]:
    print(player)

# copying
full_team = players[:]
full_team.append("steve")