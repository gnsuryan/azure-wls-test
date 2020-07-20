connect('weblogic','welcome1', 't3://localhost:7001')
print ''
print '======================================================'
print 'The script has been connected to the Admin Server'
print '======================================================'
print ''

edit()

servers=["msp1","msp2"]
ports=[8001,8002]

i = 0
while i < len(servers):
  srvrName=servers[i])
  port=ports[i]
  i += 1
 
  print ("creating server "+srvName + " at Port : "+str(port))
  
  startEdit()
  cd('/')
  cmo.createServer(srvName)
  cd('/Servers/' + srvName)
  cmo.setListenAddress("")
  cmo.setListenPort(port)
  save()

activate()

print '================================================'
print 'Completed creation of managed servers'
print '================================================'

exit()
