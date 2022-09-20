import time

n = 146
while 0 < n < 147:
    low = n * 101.42
    big = 14901 - low
    nb = big / 208.85
    fnb = str(nb).split('.')[1][0]
    # print('current n: %s, nb: %s' % (n, nb))
    # print(type(fnb))
    if low + big == 14901:
        if fnb == '0':
            print('ok, n: %s, nb: %s' % (n, nb))
            time.sleep(1)
    n -= 1

    # if (n * 101.4) + (14890 - (n * 101.4)) / 208.8 * 208.8 == 14890 & isinstance( ((n * 101.4)) / 208.8, int):
    #     print(n,  (14890 - (n * 101.4)) / 208.8)
    #     n -= 1

