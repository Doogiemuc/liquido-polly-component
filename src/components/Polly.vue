<script setup>
/**
 * Polly.vue
 *
 * A little mobile voting component.
 * In a Polly the voter doesn't cast a vote for just one proposal (or candidate).
 * Instead every voter sorts all proposal into their preferred order.
 */

import {
  ref,
  reactive,
  computed,
  onMounted,
} from 'vue';
import { VueDraggableNext as draggable } from 'vue-draggable-next';

import liquidoInput from './liquido-input.vue';
import * as pollService from '../lib/pollService';

// TODO: Not yet implemented:  Types of polls
// "CHOOSE_ONE": Each voter has one vote that he can give to exactly one proposal.
// "CHOOSE_ANY": Each voter can select one or many proposals
// "SORT":       Each voter sorts the proposals/nominations into their preferred order, from top to bottom.
// "DOT_VOTING": Each voter has a number of "dots" that he can distribute over the proposals. One proposal can receive more than one "dot".
/*
const POLL_TYPE = {
	CHOOSE_ONE: 1,
	CHOOSE_ANY: 2,
	SORT: 3,        //  <== for now only this mode is implemented since all other modes are subsets of this
	DOT_VOTING: 4
}
*/

const globalTranslations = {
  en: {
    Save: 'Save',
    Edit: 'Edit',
    Send: 'Send',
  },
  de: {
    Save: 'Speichern',
    Edit: 'Bearbeiten',
    Send: 'Senden',
  },
};

const messages = {
  en: {
    AddProposalPlaceholder: 'Add another proposal',
    PollyTitlePlaceholder: 'Polly Title',
    PollyTitleEmptyFeedback:
      'Please enter a title (at least {minLength} characters).',
    PollyTitleInvalidFeedback:
      'Title is too short, minimum {minLength} characters.',
    StartPollInfo:
      'You’ll receive a private admin link to manage your poll, and a public voting link to share with your friends.',
    StartPoll: 'Start Poll',
    FinishPoll: 'Finish Poll',
    CastVote: 'Cast Vote',
    NewPolly: 'New Polly',
    PollNotYetStarted: 'Poll not yet started',
    StartingPoll: 'Starting poll ...',
    SortProposals: 'Sort proposals',
    ThxForVoting: 'THX for voting!',
    PollIsFinished: 'Poll is finished ({numVoters} voters)',
  },
  de: {
    AddProposalPlaceholder: 'Vorschlag hinzufügen',
    PollyTitlePlaceholder: 'Polly Titel',
    PollyTitleEmptyFeedback:
      'Bitte gib einen Titel ein (mindestens {minLength} Zeichen).',
    PollyTitleInvalidFeedback:
      'Titel ist zu kurz. Bitte mindestens {minLength} Zeichen.',
    StartPollInfo:
      'Ich schicke dir zwei Links: Einen privaten Admin-Link nur für dich. Und einen öffentlchen Link für deine Freunden, mit dem sie abstimmen können.',
    StartPoll: 'Abstimmung starten',
    FinishPoll: 'Abstimmung beenden',
    CastVote: 'Abstimmen',
    NewPolly: 'Neues Polly',
    PollNotYetStarted: 'Noch nicht gestartet',
    StartingPoll: 'Wird gestartet ...',
    SortProposalsInfo: 'Ordne die Vorschläge so wie es dir gefällt.',
    ThxForVoting: 'Danke für deine Stimme!',
    PollIsFinished: 'Diese Abstimmung ist beendet. ({numVoters} Teilnehmer)',
  },
};

/**
 * Unbelievablly clever localization function. Supports:
 * fallback to another language, global translations, and parameter replacement.
 * @param key The key to be localized
 * @param params An object with parameters to replace in the localized string
 */
function loc(key, params = {}) {
  const lang = 'de'; // TODO: navigator.language.startsWith("en") ? "en" : "de";
  let message;

  if (messages[lang] && messages[lang][key]) {
    message = messages[lang][key];
  } else if (messages['en'] && messages['en'][key]) {
    message = messages['en'][key];
  } else if (globalTranslations[lang] && globalTranslations[lang][key]) {
    message = globalTranslations[lang][key];
  } else if (globalTranslations['en'] && globalTranslations['en'][key]) {
    message = globalTranslations['en'][key];
  } else {
    console.warn("Missing translation for key '" + key + "'");
    return key;
  }

  return message.replace(/\{(\w+)\}/g, (match, placeholder) => {
    return params.hasOwnProperty(placeholder) ? params[placeholder] : match;
  });
}

/* Status flow of a poll */
const POLL_STATUS = {
  NEW: 'NEW',
  ELABORATION: 'ELABORATION',
  PREPARE_START: 'PREPARE_START', // this status only exists in the frontend. Here we ask for user's email
  IN_VOTING: 'VOTING',
  FINISHED: 'FINISHED',
};

const props = defineProps({
  poll: {
    type: Object,
    required: true,
  },
  mode: {
    type: String,
    default: 'admin',
    validator: (value) => ['admin', 'voter'].includes(value)
  },
  pollToken: {
    type: String,
    default: null
  }
});

// The prop is the initial value. Here we copy that to a local proxy that can change.
// https://vuejs.org/guide/components/props.html#one-way-data-flow
// TODO: use provide-inject instead: https://vuejs.org/guide/components/provide-inject.html#app-level-provide
//console.log("props", JSON.stringify(props, null, 2))
const poll = reactive(props.poll);

/*
Example "poll" object with its properties:

		{
			"title": "What shall we do tonight?",
			"proposals": [   // Proposals have an sorted order in this array!
				{
					"id": 4711   // any arbitrary ID
					"title": "Go to Rave",
				},
				{
					"id": 4712
					"title": "Go a nice restaurant and do some dinner",
				},
				{
					"id": 4713
					"title": "Cinema is nice",
				}
			],
			"status": "VOTING",
			"alreadyVoted": false,  // Has the current user already casted a vote in this poll
			"numVoters": 0,        // How many persons have casted their vote in this poll.
		}

*/

/**
 * Initialize default values of poll if not yet set
 * My dear VUE: tell my how to do this otherwise! :-)
 */
Object.assign(poll, {
  status: POLL_STATUS.NEW,
  numVoters: 0,
});
if (poll.proposals == undefined) poll.proposals = [];

// Must have at least two proposals. And add IDs
for (let i = 0; i < poll.proposals.length || i < 2; i++) {
  if (!poll.proposals[i]) poll.proposals[i] = {};
  const prop = poll.proposals[i];
  if (!prop.id) prop.id = Date.now() + i; // random unique ID
  if (!prop.title) prop.title = '';
  // if (!prop.votes) prop.votes = 0  // only needed for other poll types
}

// IF  Poll is new
// AND last element has a title
// THEN add another empty proposal input at the bottom.
// (It will be removed when saving.)
if (poll.status == POLL_STATUS.NEW && propHasTitle(poll.proposals.length - 1))
  addProposal();

const user = reactive({
  id: Date.now(),
  name: 'Donald Duck',
  email: 'dummy@domain.org',
});

const isAdminMode = computed(() => props.mode === 'admin');
const isVoterMode = computed(() => props.mode === 'voter');
const voterId = ref(null);
const isSavingVote = ref(false);

// ========== Computed Properties ===========

const isNew = computed(() => poll.status == POLL_STATUS.NEW);
const inElaboration = computed(() => poll.status == POLL_STATUS.ELABORATION);
const prepareStart = computed(() => poll.status == POLL_STATUS.PREPARE_START);
const inVoting = computed(() => poll.status == POLL_STATUS.IN_VOTING);
const isFinished = computed(() => poll.status == POLL_STATUS.FINISHED);

function pollTitleValid() {
  return typeof poll.title === 'string' && poll.title.trim().length >= 10;
}

/** A poll needs at least a title and two proposals */
const saveIsActive = computed(() => {
  return pollTitleValid() && propHasTitle(0) && propHasTitle(1);
});

const userEmailIsValid = computed(() => {
  return isEmail(user.email);
});

// ========== Methods ===========
function propHasTitle(index) {
  const title = poll.proposals?.[index]?.title;
  return typeof title === 'string' && title.trim().length > 0;
}

/** Popup when user clicks save. */
let askEmailModal;

onMounted(async () => {
  console.log('Polly poll', poll);
  askEmailModal = new bootstrap.Modal(
    document.getElementById('askEmailModal'),
    {}
  );
  const pollTitleInput = document.getElementById('pollTitleInput');
  if (pollTitleInput) pollTitleInput.focus();

  if (isVoterMode.value && props.pollToken) {
    voterId.value = getOrCreateVoterId();
    try {
      const alreadyVoted = await pollService.hasVoted(poll.id, voterId.value);
      poll.alreadyVoted = alreadyVoted;
    } catch (error) {
      console.error('Error checking vote status:', error);
    }
  }
});

function addProposal() {
  poll.proposals.push({
    id: Date.now(), // random unique ID
    title: '',
  });
}

function deleteProposal(index) {
  console.log('deleteProposal(index=' + index + ')');
  if (poll.proposals.length <= 2) return; // Must always have at lest two proposal inputs
  poll.proposals.splice(index, 1);
}

/**
 * GIVEN user leaves an input field
 *   AND there are more than two input fields
 *  WHEN an input field is empty
 *  THEN delete it
 *  ELSE
 *  WHEN the last input field is filled
 *  THEN add another input field at the bottom.
 */
function onProposalBlurr(evt, index) {
  let len = poll.proposals.length;
  if (len >= 2 && poll.proposals[index]) {
    if (index < len - 1 && !propHasTitle(index)) {
      deleteProposal(index);
    } else if (index === len - 1 && propHasTitle(index)) {
      addProposal();
    }
  }
}

/**
 * Find proposals with duplicate titles. And mark the input fields as invalid.
 * Empty titles are ok.
 * (This code is AI generated.)
 */
function checkForDuplicateTitles() {
  let pollyProposalInputs =
    document.getElementsByClassName('polly-proposal-input') || [];
  // This may happen in some very exceptional cases. But marking is fine.
  if (pollyProposalInputs.length != poll.proposals.length) {
    return;
  }

  // Create a map to track occurrences of each title
  const titleOccurrences = new Map();

  // Step 1: Count occurrences of each non-empty title
  for (let i = 0; i < poll.proposals.length; i++) {
    const title = poll.proposals[i].title.trim();
    if (title !== '') {
      if (!titleOccurrences.has(title)) {
        titleOccurrences.set(title, []);
      }
      titleOccurrences.get(title).push(i); // Store the indices where the title appears
    }
  }

  // Step 2: Mark inputs as valid/invalid based on duplicates
  for (let i = 0; i < poll.proposals.length; i++) {
    const title = poll.proposals[i].title.trim();

    if (title !== '' && titleOccurrences.get(title)?.length > 1) {
      // If the title is duplicated, add the "is-invalid" class
      pollyProposalInputs[i].classList.add('is-invalid');
    } else {
      // Otherwise, remove the "is-invalid" class
      pollyProposalInputs[i].classList.remove('is-invalid');
    }
  }
}

/**
 * If last proposals is filled, then add a new empty one below.
 * If user pressed enter on an empty title, remove this proposal. But only if there are more then two proposals.
 * Then check for duplicate titles.
 */
function onProposalKeyup(evt, index) {
  let len = poll.proposals.length;
  if (index === len - 1 && propHasTitle(index)) {
    addProposal();
  } else if (evt.key == 'Enter' && len >= 2 && !propHasTitle(index)) {
    deleteProposal(index);
  } else {
    checkForDuplicateTitles();
  }
}

/**
 * Save the edited poll.
 * (Removes the last porposal if its title is empty.)
 */
function savePoll() {
  if (!propHasTitle(poll.proposals.length - 1)) poll.proposals.pop();
  poll.status = POLL_STATUS.ELABORATION;
}

/** Go back to edit mode. This is only allowed if there no votes yet. */
function editPoll() {
  poll.status = POLL_STATUS.NEW;
  onProposalKeyup({}, poll.proposals.length - 1); // to add an empty proposal at the end
}

function clickStartPollButton() {
  poll.status = POLL_STATUS.PREPARE_START;
  askEmailModal.show();
  //Debug: poll.status = POLL_STATUS.IN_VOTING
}

async function startPoll() {
  try {
    const pollData = await pollService.createPoll(
      poll.title,
      poll.proposals.filter(p => p.title.trim()),
      user.email
    );
    askEmailModal.hide();
    console.log('Poll created:', pollData);
    console.log('Admin link: ?admin=' + pollData.admin_token);
    console.log('Voter link: ?vote=' + pollData.vote_token);
    poll.status = POLL_STATUS.IN_VOTING;
    poll.id = pollData.id;
  } catch (error) {
    console.error('Error starting poll:', error);
    alert('Failed to start poll. Please try again.');
  }
}

function cancelStartPoll() {
  poll.status = POLL_STATUS.ELABORATION;
}

function devReopenPoll() {
  poll.status = POLL_STATUS.ELABORATION;
}

async function castVote() {
  if (isSavingVote.value) return;

  isSavingVote.value = true;
  try {
    const voteOrder = poll.proposals.map(p => p.id);
    await pollService.castVote(poll.id, voterId.value, voteOrder);
    poll.numVoters++;
    poll.alreadyVoted = true;
  } catch (error) {
    console.error('Error casting vote:', error);
    alert('Failed to cast vote. Please try again.');
  } finally {
    isSavingVote.value = false;
  }
}

function getOrCreateVoterId() {
  const storageKey = `polly_voter_${poll.id}`;
  let id = localStorage.getItem(storageKey);
  if (!id) {
    id = pollService.generateVoterId();
    localStorage.setItem(storageKey, id);
  }
  return id;
}

async function finishPoll() {
  try {
    await pollService.updatePollStatus(poll.id, 'FINISHED');
    poll.status = POLL_STATUS.FINISHED;
  } catch (error) {
    console.error('Error finishing poll:', error);
    alert('Failed to finish poll. Please try again.');
  }
}

/** Check if a string looks like an email adress */
const eMailRegEx = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,64}/;
function isEmail(s) {
  return eMailRegEx.test(s);
}
</script>

<template>
  <div class="polly">
    <div class="card polly-card position-relative user-select-none">
      <span
        v-if="inVoting"
        @click="shareLinkToPoll"
        class="fa-stack share-poll-icon"
        title="Share Poll"
      >
        <i
          class="fa-solid fa-circle fa-stack-2x"
          style="color: var(--icon-bg)"
        ></i>
        <i class="fa-solid fa-arrow-up-from-bracket fa-stack-1x"></i>
      </span>
      <div class="card-header">
        <liquido-input
          v-if="isNew"
          id="pollTitleInput"
          class="poll-title-input"
          v-model="poll.title"
          :minLength="10"
          :required="true"
          :placeholder="loc('PollyTitlePlaceholder')"
          :empty-feedback="loc('PollyTitleEmptyFeedback', { minLength: 10 })"
          :invalid-feedback="
            loc('PollyTitleInvalidFeedback', { minLength: 10 })
          "
          :feedback-placeholder="true"
        />

        <!-- input v-if="isNew" 
					id="pollTitleInput"
					type="text" 
					class="form-control poll-title-input"  
					v-model="poll.title"
					placeholder="Polly Title" 
					:validFunc="pollTitleValid" 
					:feedback-placehoder=true 
					:invalid-feedback="loc('PollTitleInvalid')"
				/ -->
        <h2 v-else class="poll-title" id="pollTitle">{{ poll.title }}</h2>
      </div>

      <div v-if="isNew" class="card-body">
        <TransitionGroup class="polly-proposals-wrapper" tag="ul">
          <li
            v-for="(prop, index) in poll.proposals"
            :key="prop.id"
            class="polly-proposal d-flex align-items-center"
          >
            <input
              v-model="prop.title"
              :placeholder="loc('AddProposalPlaceholder')"
              type="text"
              class="form-control flex-grow-1 polly-proposal-input"
              @blur="(evt) => onProposalBlurr(evt, index)"
              @keyup="(evt) => onProposalKeyup(evt, index)"
            />
          </li>
        </TransitionGroup>
      </div>

      <div v-if="inElaboration || prepareStart || isFinished" class="card-body">
        <!-- read-only view of the poll -->
        <div class="polly-proposals-wrapper position-relative">
          <div
            v-for="(proposal, index) in poll.proposals"
            class="polly-proposal d-flex align-items-center"
          >
            <div v-if="isFinished" class="text-secondary me-2">
              {{ index + 1 }}.
            </div>
            <div class="flex-grow-1 form-control readonly-proposal border-0">
              {{ proposal.title }}
            </div>
          </div>
        </div>
      </div>

      <div v-if="inVoting" class="card-body d-flex flex-row">
        <!-- poll inVoting where user can drag proposals up and down -->
        <div class="me-1">
          <div
            v-for="(prop, index) in poll.proposals"
            :key="prop.id"
            class="proposal-index-number form-control"
          >
            {{ index + 1 }}.
          </div>
        </div>
        <div class="polly-proposals-wrapper">
          <draggable
            id="draggableProposals"
            v-model="poll.proposals"
            itemKey="id"
            :animation="500"
            can-scroll-x="false"
            :disabled="poll.alreadyVoted"
          >
            <div
              v-for="prop in poll.proposals"
              :class="['polly-proposal sortable-proposal d-flex align-items-center position-relative form-control border-0', { 'voted-disabled': poll.alreadyVoted }]"
            >
              <div class="sortable-proposal-content">
                {{ prop.title }}
              </div>
            </div>
          </draggable>
        </div>
      </div>
      <div v-if="inVoting" class="sort-proposal-info">
        {{ loc('SortProposalsInfo') }}
      </div>

      <div class="card-footer">
        <!-- poll footer with status and buttons -->
        <div class="d-flex align-items-center justify-content-end">
          <div v-if="isNew" class="text-end">
            <button
              @click="savePoll"
              :disabled="!saveIsActive"
              type="button"
              class="btn btn-sm btn-primary"
            >
              <i class="fa-regular fa-save"></i>&nbsp;{{ loc('Save') }}
            </button>
          </div>
          <div v-if="inElaboration" class="text-end">
            <button
              @click="editPoll"
              type="button"
              class="btn btn-sm btn-secondary me-2"
            >
              <i class="fa-regular fa-edit"></i>&nbsp;{{ loc('Edit') }}
            </button>
            <button
              @click="clickStartPollButton"
              type="button"
              class="btn btn-sm btn-primary"
            >
              <i class="fa-solid fa-play"></i>&nbsp;{{ loc('StartPoll') }}
            </button>
          </div>
          <div v-if="prepareStart" class="text-end">
            <button
              type="button"
              class="btn btn-sm btn-primary disabled"
              disabled
            >
              <i class="fa-solid fa-play"></i>&nbsp;{{ loc('StartPoll') }}
            </button>
          </div>
          <div v-if="inVoting" class="text-end">
            <button
              v-if="isAdminMode"
              @click="finishPoll"
              type="button"
              class="btn btn-sm btn-secondary me-2"
            >
              <i class="fa-regular fa-circle-check"></i>&nbsp;{{
                loc('FinishPoll')
              }}
            </button>
            <button
              v-if="!poll.alreadyVoted"
              @click="castVote"
              type="button"
              class="btn btn-sm btn-primary"
              :disabled="isSavingVote"
            >
              <i class="fa-solid fa-person-booth"></i>&nbsp;{{
                isSavingVote ? 'Saving...' : loc('CastVote')
              }}
            </button>
            <div v-if="poll.alreadyVoted && isVoterMode" class="text-success">
              <i class="fa-solid fa-check-circle"></i>&nbsp;{{ loc('ThxForVoting') }}
            </div>
          </div>
          <div v-if="isFinished" class="text-end">
            <i class="fa-solid fa-person-booth"></i>&nbsp;{{
              loc('PollIsFinished', { numVoters: poll.numVoters })
            }}
          </div>
        </div>
      </div>
    </div>

    <!-- Bootstrap Modal: Ask user for their email -->
    <div
      class="modal"
      id="askEmailModal"
      data-bs-backdrop="static"
      tabindex="-1"
      aria-labelledby="askEmailModalLabel"
    >
      <div class="modal-dialog">
        <div class="modal-content">
          <div class="modal-header bg-secondary-subtle">
            <h4 class="modal-title" id="askEmailModalLabel">
              {{ loc('StartPoll') }}
            </h4>
            <button
              type="button"
              class="btn-close"
              data-bs-dismiss="modal"
              aria-label="Close"
              @click="cancelStartPoll"
            ></button>
          </div>
          <div class="modal-body">
            {{ loc('StartPollInfo') }}
            <div class="d-flex mt-2">
              <div class="flex-grow-1">
                <input
                  id="userEmailInput"
                  type="email"
                  v-model="user.email"
                  class="form-control form-control-sm"
                  placeholder="Your email"
                  @keyup.enter="userEmailIsValid && startPoll()"
                  aria-label="Your Email"
                />
              </div>
              <div>
                <button
                  type="button"
                  class="btn btn-primary btn-sm ms-2"
                  data-bs-dismiss="modal"
                  @click="startPoll"
                  :disabled="!userEmailIsValid"
                >
                  {{ loc('Send') }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style lang="scss">
// A bootstrap card for creating a poll

$arrow-size: 8px;
$proposal-bg: #e6f0ff;
$polly-proposal-height: 40px;
$polly-proposal-margin-bottom: 16px;

.polly-card {
  max-width: 1024px;

  .card-header {
    border-bottom: none;
  }

  .share-poll-icon {
    cursor: pointer;
    color: var(--icon-color);
    position: absolute;
    top: -0.4rem;
    right: -0.4rem;

    &:hover {
      color: var(--primary);
    }
  }

  .poll-title-input {
    text-align: center;
    input {
      //font-size: 1.25rem;
      font-weight: bold;
      text-align: center;
    }
  }

  .poll-title {
    margin: 0;
    padding: 0;
    //font-size: 1.25rem;
    font-weight: bold;
    text-align: center;
  }

  .polly-proposal-input::placeholder {
    color: lightgrey;
  }

  .readonly-proposal {
    background-color: var(--bs-secondary-bg);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .pos-top-middle {
    position: absolute;
    top: -$arrow-size;
    left: 50%;
  }

  .pos-bottom-middle-down {
    position: absolute;
    bottom: -$arrow-size;
    left: 50%;
    transform: rotate(180deg);
  }

  .arrow-triangle {
    width: 0;
    height: 0;
    border-left: $arrow-size solid transparent;
    border-right: $arrow-size solid transparent;
    border-bottom: $arrow-size solid $proposal-bg;
  }

  // Polly footer
  .card-footer {
    border-top: none;
  }
}

// ======== Proposals List =============
// Each proposal has a fixed height and a margin-bottom.
// This is important for the VUE list transition to work properly.

// Wrapper around the proposals list
.polly-proposals-wrapper {
  position: relative;
  padding: 0;
  margin: 0;
  list-style-type: none;
  min-width: 0; // must set to keep flexbox from growing too wide
  flex-grow: 1;
}

// Each proposal. This is used for editable and non-editable views.
.polly-proposal {
  height: $polly-proposal-height;
  box-sizing: border-box;

  &:not(:last-child) {
    margin-bottom: $polly-proposal-margin-bottom;
  }
}

// The index number at the left side of the sortable proposals. (These are fixed and don't move.)
.proposal-index-number {
  height: $polly-proposal-height;
  font-size: 1.1rem;
  &:not(:last-child) {
    margin-bottom: $polly-proposal-margin-bottom;
  }
}

// additional styles for sortable proposals
.sortable-proposal {
  background-color: $proposal-bg !important;

  &.voted-disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }
}

.sortable-proposal-content {
  flex-grow: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.drag-handle {
  width: 2rem;
  height: 2rem;
  //color: black;
}

.sort-proposal-info {
  text-align: center;
  color: var(--bs-secondary);
  margin-bottom: 1rem;
}

// ========= Slid-up VUE transition - used for status in footer ========
// adapted from https://vuejs.org/guide/built-ins/transition
.slide-up-enter-active,
.slide-up-leave-active {
  transition: all 0.5s ease-out;
}

.slide-up-enter-from {
  opacity: 0;
  //transform: translateY(30px);
}

.slide-up-leave-to {
  opacity: 0;
  //transform: translateY(-30px);
}

// ========= For VUE.draggable@next ========

.ghost {
  // for drop placeholder
  //border: 1px solid red;
}

.chosen {
  // for the chosen item
  opacity: 0.3;
}

.drag {
  // for the dragging item
  //opacity: 1.0;
  //border: 1px solid blue !important;
}

//===== small utility classes =======

.cursor-move {
  cursor: move;
}

.info-icon {
  font-size: 0.5rem;
  margin-left: 0.25rem;
}

.thx-for-voting {
  transition: opacity;
  transition-duration: 1s;
  opacity: 0;
}

.thx-for-voting-show {
  opacity: 1;
}

#askEmailModal .modal-dialog {
  margin-top: 5rem; // space for liquido-header
}
</style>
