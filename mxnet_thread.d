/*

Sample D trace script. Usage:

dtrace -s mxnet_thread.d -p `cat logs/$HOSTNAME.murexnet*.pid` -o mxnet_thread_dtrace_`date '+%d%m%y_%H%M%S'`.log

*/

proc:::lwp-start
/ pid == $target /
{
  self->unpaired_locks = 0;
}


pid$target::Sys_ThreadEntry:entry
{
    /* MDSYS_THRD->pPrm */
    this->pPrm=*(uint32_t *)copyin(arg0+0xc,4);
    this->clientid=*(int *)copyin(this->pPrm+0x5c,4);
    this->socket=*(int *)copyin(this->pPrm+0x68,4);
    this->ip=(char *)copyin(this->pPrm+0xd8,20);
    this->lpid=*(int *)copyin(this->pPrm+0x1ec,20);
    /* printf("%d tid=%d: New Thread socket=%d clientID=%d IP=%s pid=%d\n", timestamp, tid, this->socket, this->clientid, stringof(this->ip), this->lpid); */ 
}

/*
pid$target::pthread_mutex_lock:entry
{
    @count_all[ustack()] = count();
}
*/

pid$target::pthread_mutex_lock:entry
{
    this->mutex_lockword=*(char *)copyin(arg0+0xf,1); /* To get the lock word! */
/*    printf("Mutex lock entry on thread: %d, mutex address: %x , lock word = %d\n", tid, arg0, this->mutex_lockword); */
    @count_entry[probemod, probefunc, probename, this->mutex_lockword] = count(); 
}

pid$target::pthread_mutex_unlock:entry
{
    this->mutex_lockword=*(char *)copyin(arg0+0xf,1); /* To get the lock word! */
    @count_entry[probemod, probefunc, probename, this->mutex_lockword] = count(); 
}

pid$target::pthread_mutex_unlock:entry
/ *(char *)copyin(arg0+0xf,1) ==0 /
{
    @count_unlock_on_unlocked_stacks[ustack()] = count();
}

pid$target::pthread_mutex_destroy:entry
{
    this->mutex_lockword=*(char *)copyin(arg0+0xf,1); /* To get the lock word! */
    @count_entry[probemod, probefunc, probename, this->mutex_lockword] = count(); 
}

pid$target::pthread_mutex_lock:return
{   
    /* printf("Mutex lock return, arg0 = %d, arg1 = %d\n", arg1); */
    @count_return[probemod, probefunc, probename, arg1] = count(); 
}

pid$target::pthread_mutex_unlock:return 
{
    @count_return[probemod, probefunc, probename, arg1] = count(); 
}


pid$target::pthread_mutex_destroy:return
{
  @count_return[probemod, probefunc, probename, arg1] = count(); 
}

/*
proc:::lwp-exit
/ pid == $target &&  self->unpaired_locks > 0  /
{
  printf("Thread exit while a mutex is being held: "); 
  printf("%d tid=%d func=%s unpaired_locks=%d\n", timestamp, tid, probefunc, self->unpaired_locks);
  printf("\nUser Stack:\n");
  ustack();
}
*/

dtrace:::END
{
    printa(@count_entry);
    printa(@count_return);
/*  printa(@count_all);*/
    printa(@count_unlock_on_unlocked_stacks); 
}

