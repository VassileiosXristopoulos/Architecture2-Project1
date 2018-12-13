import random

_file = open("data", "w")
random_data = ['0x' + ''.join(random.choice('0123456789ABCDEF') for _ in range(16)) for _ in range(150)]
_file.write(".data\nA:\t" + ".word " + ".word ".join([v + "\n\t" for v in random_data]))
_file.close()