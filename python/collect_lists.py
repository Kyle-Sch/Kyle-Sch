bicyclyes = ["trek", "cannondale", "redline", "specialized"]
print(bicyclyes)
print(bicyclyes[0])
print(bicyclyes[0].title())

message = f"My first bike was a {bicyclyes[1].title()}."
print(message)

motorcyles = ['honda', 'yamaha', 'suzuki']
print(motorcyles)
motorcyles[0] = 'ducati'
print(motorcyles)

motorcyles.append('davidson')
print(motorcyles)

motorcyles.insert(0, 'harley')
print(motorcyles)

del motorcyles[0]
print(motorcyles)

lastMotorcyle = motorcyles.pop()
print(lastMotorcyle)
print(motorcyles)

firstMotorcyle = motorcyles.pop(0)
print(firstMotorcyle)
print(motorcyles)

motorcyles.remove("honda")
print(motorcyles)

# Sorting
motorcyles.sort() #Perm
print(motorcyles)

motorcyles.sort(reverse=True)
print(motorcyles)

print(sorted(motorcyles)) # Temp

motorcyles.reverse()
print(motorcyles)

len(motorcyles) # length

print(motorcyles[-1]) # last value

# Split
players = ["kyle", "mike", "corey"]
print(players[0:2])
print(players[:2])
print(players[-1:]) # digits from the end