<script setup>
//import HelloWorld from './components/HelloWorld.vue'
import Polly from './components/Polly.vue'

const examplePoll = {
	title: "What shall we do tonight?",
	proposals: [
		{ title: "Go to Rave" },
		{ title: "Go a nice restaurant and do some dinner  and a very long text to test breaking of lines" },
		{ title: "Cinema is nice" }
	]
}
</script>

<template>
	<div>
		<Polly :poll="examplePoll"></Polly>
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
