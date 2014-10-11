
#include "tim.h"

TIM_CTL timerCtl;
extern TIM* task_timer;
extern TASK_CTL taskCtl;

void interrupt_handler_0x20(int32 *esp)
{
	uint8 i, j;
	io_out8(PIC0_OCW2, 0x60);		//��IRQ-00�źŽ��ս�������Ϣ֪ͨ��PIC

	timerCtl.timecount++;

	if(timerCtl.sortedEnd != 0 && timerCtl.timecount >= timerCtl.sortedTimer[0]->timeout) {	//�ж�ʱ����ʱ
		for(i = 0; i < timerCtl.sortedEnd && timerCtl.timecount >= timerCtl.sortedTimer[i]->timeout; i++);
		for(j = 0; j < i; j++) {
			timerCtl.sortedTimer[j]->isTimeout = TRUE;
			timerCtl.timeoutTimer[timerCtl.timeoutEnd++] = timerCtl.sortedTimer[j];
		}
		for(j = i; j < timerCtl.sortedEnd; j++) {
			timerCtl.sortedTimer[j - i] = timerCtl.sortedTimer[j];
		}
		timerCtl.sortedEnd -= i;
		timerCtl.sortedTimer[0] = (timerCtl.sortedEnd == 0) ? NULL : timerCtl.sortedTimer[0];

		if(task_timer != NULL && task_timer->isUsing == TRUE && task_timer->isTimeout == TRUE) {
			multiTask_switch();
		}
	}
	
	if(taskCtl.sleepTasksEnd > 0) {
		// �ҵ���ʱ�� sleep �����е�λ��
		for(i = 0; i < taskCtl.sleepTasksEnd && taskCtl.sleepTasks[i]->sleepTimeCnt_10ms <= timerCtl.timecount; i++);
		// �����г�ʱ������ŵ����ж�����
		for(j = 0; j < i; j++) {
			taskCtl.sleepTasks[j]->status = running;
			taskCtl.runningTasks[taskCtl.runningTasksEnd++] = taskCtl.sleepTasks[j];
		}
		// �� sleep ������ɾ����Щ����
		for(j = i; j < taskCtl.sleepTasksEnd; j++) {
			taskCtl.sleepTasks[j - i] = taskCtl.sleepTasks[j];
		}
		// ���е���
		multiTask_switch();
	}
	
}

void tim_init()
{
	int i = 0;
	timerCtl.sortedEnd = 0;
	timerCtl.timeoutEnd = 0;
	timerCtl.timecount = 0;
	timerCtl.timerPos = 0;
	for(; i < MAX_TIMER; i++) {
		timerCtl.sortedTimer[i] = NULL;
		timerCtl.timeoutTimer[i] = NULL;
		timerCtl.timers[i].isUsing = FALSE;
	}
	
	io_out8(PIT_CTRL, 0x34);
	// ����Ϊ 0x2e9c, һ��Լ�ж�100��
	io_out8(PIT_CNT0, 0x9c);
	io_out8(PIT_CNT0, 0x2e);
}

boolean timer_add(IN uint32 timeout, OUT TIM** timer)
{
	if(timerCtl.sortedEnd >= MAX_TIMER) {
		timer = NULL;
		return FALSE;
	}
	for(;timerCtl.timers[timerCtl.timerPos].isUsing == TRUE;timerCtl.timerPos = (timerCtl.timerPos + 1) % MAX_TIMER);

	(*timer) = &(timerCtl.timers[timerCtl.timerPos]);
	(*timer)->timeout = timeout + timerCtl.timecount;
	if((*timer)->timeout < timerCtl.timecount) {
		tim_revise();
	}
	(*timer)->timeout = timeout + timerCtl.timecount;
	(*timer)->isUsing = TRUE;
	(*timer)->isTimeout = FALSE;
	timerCtl.sortedTimer[timerCtl.sortedEnd] = (*timer);
	timerCtl.sortedEnd++;
	timerCtl.timerPos = (timerCtl.timerPos + 1) % MAX_TIMER;
	tim_sort();
	return TRUE;
}

boolean timer_set_timeout(IN TIM* timer, IN uint32 timeout)
{
	int32 i, j;
	if(timer == NULL || timer->isUsing == FALSE)
		return FALSE;
	
	for(i = 0; i < timerCtl.timeoutEnd && timer != timerCtl.timeoutTimer[i]; i++);
	if(i >= timerCtl.timeoutEnd) {
		for(i = 0; i < timerCtl.sortedEnd && timer != timerCtl.sortedTimer[i]; i++);
		if(i >= timerCtl.sortedEnd)		//δ�ҵ��� ��ʱ��
			return FALSE;
		//������ʱ����������
		timer->timeout = timeout + timerCtl.timecount;
		if(timer->timeout < timerCtl.timecount) {
			tim_revise();
		}
		tim_sort();
	}
	else {		//�ڳ�ʱ�Ķ������ҵ��˸� ��ʱ��(λ��Ϊ i)������ӳ�ʱ�����ƶ����������
		for(j = i + 1; j < timerCtl.timeoutEnd; j++) {
			timerCtl.timeoutTimer[j - 1] = timerCtl.timeoutTimer[j];
		}
		timerCtl.timeoutEnd--;

		timer->timeout = timeout + timerCtl.timecount;
		if(timer->timeout < timerCtl.timecount) {
			tim_revise();
		}
		timer->isTimeout = FALSE;
		timerCtl.sortedTimer[timerCtl.sortedEnd++] = timer;
		tim_sort();
	}
	return TRUE;
}

boolean timer_del(IN TIM* timer)
{
	int i;
	for(i = 0; i < timerCtl.timeoutEnd && timerCtl.timeoutTimer[i] != timer; i++);
	if(i == timerCtl.timeoutEnd) {
		return FALSE;
	}
	for(; i < timerCtl.timeoutEnd - 1; i++) {
		timerCtl.timeoutTimer[i] = timerCtl.timeoutTimer[i + 1];
	}
	timer->isUsing = FALSE;
	return TRUE;
}

boolean timer_is_valid(IN TIM* timer)
{
	int32 i;
	for(i = 0; i < MAX_TIMER && timer != &(timerCtl.timers[i]); i++);
	if(i < MAX_TIMER)
		return TRUE;
	else 
		return FALSE;
}

uint32	timer_getcount()
{
	return timerCtl.timecount;
}

void tim_revise()
{
	uint32 t, i;
	io_cli();
	t = timerCtl.timecount;
	for(i = 0; i < timerCtl.sortedEnd; i++) {
		timerCtl.sortedTimer[i]->timeout -= t;
	}
	timerCtl.timecount = 0;
	io_sti();
}

void tim_sort()
{
	int i, j;
	TIM* tmpTimer;
	for(i = timerCtl.sortedEnd; i > 0; i--) {
		for(j = 0; j < i - 1; j++) {
			if(timerCtl.sortedTimer[j]->timeout > timerCtl.sortedTimer[j + 1]->timeout) {
				tmpTimer = timerCtl.sortedTimer[j];
				timerCtl.sortedTimer[j] = timerCtl.sortedTimer[j + 1];
				timerCtl.sortedTimer[j + 1] = tmpTimer;
			}
		}
	}
}
