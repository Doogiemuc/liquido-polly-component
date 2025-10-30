<script setup>
import { ref, onMounted } from 'vue'
import Polly from './components/Polly.vue'
import * as pollService from './lib/pollService'

const examplePoll = {
	title: "What shall we do tonight?",
	proposals: [
		{ title: "Go to Rave" },
		{ title: "Go a nice restaurant and do some dinner  and a very long text to test breaking of lines" },
		{ title: "Cinema is nice" }
	]
}

const pollData = ref(examplePoll)
const mode = ref('admin')
const pollToken = ref(null)
const isLoading = ref(false)

onMounted(async () => {
	const urlParams = new URLSearchParams(window.location.search)
	const voteToken = urlParams.get('vote')
	const adminToken = urlParams.get('admin')

	if (voteToken || adminToken) {
		isLoading.value = true
		try {
			const token = voteToken || adminToken
			const isAdmin = !!adminToken
			const poll = await pollService.getPollByToken(token, isAdmin)

			if (poll) {
				pollData.value = poll
				mode.value = isAdmin ? 'admin' : 'voter'
				pollToken.value = token
			} else {
				console.error('Poll not found')
			}
		} catch (error) {
			console.error('Error loading poll:', error)
		} finally {
			isLoading.value = false
		}
	}
})
</script>

<template>
	<div>
		<div v-if="isLoading" class="text-center p-5">
			<div class="spinner-border" role="status">
				<span class="visually-hidden">Loading...</span>
			</div>
		</div>
		<Polly v-else :poll="pollData" :mode="mode" :pollToken="pollToken"></Polly>
	</div>
</template>

<style scoped>
.logo {
  height: 6em;
  padding: 1.5em;
  will-change: filter;
  transition: filter 300ms;
}
.logo:hover {
  filter: drop-shadow(0 0 2em #646cffaa);
}
.logo.vue:hover {
  filter: drop-shadow(0 0 2em #42b883aa);
}
</style>
