import { supabase } from './supabase'

export async function createPoll(title, proposals, adminEmail) {
  const { data: poll, error: pollError } = await supabase
    .from('polls')
    .insert({
      title,
      status: 'VOTING',
      admin_email: adminEmail,
      num_voters: 0
    })
    .select()
    .single()

  if (pollError) throw pollError

  const proposalsData = proposals.map((prop, index) => ({
    poll_id: poll.id,
    title: prop.title,
    sort_order: index
  }))

  const { error: proposalsError } = await supabase
    .from('proposals')
    .insert(proposalsData)

  if (proposalsError) throw proposalsError

  return poll
}

export async function getPollByToken(token, isAdmin = false) {
  const { data: poll, error: pollError } = await supabase
    .from('polls')
    .select('*')
    .eq(isAdmin ? 'admin_token' : 'vote_token', token)
    .maybeSingle()

  if (pollError) throw pollError
  if (!poll) return null

  const { data: proposals, error: proposalsError } = await supabase
    .from('proposals')
    .select('*')
    .eq('poll_id', poll.id)
    .order('sort_order')

  if (proposalsError) throw proposalsError

  return {
    ...poll,
    proposals: proposals.map(p => ({
      id: p.id,
      title: p.title
    }))
  }
}

export async function hasVoted(pollId, voterId) {
  const { data, error } = await supabase
    .from('votes')
    .select('id')
    .eq('poll_id', pollId)
    .eq('voter_id', voterId)
    .maybeSingle()

  if (error) throw error
  return !!data
}

export async function castVote(pollId, voterId, voteOrder) {
  const { error: voteError } = await supabase
    .from('votes')
    .insert({
      poll_id: pollId,
      voter_id: voterId,
      vote_order: voteOrder
    })

  if (voteError) throw voteError

  const { error: updateError } = await supabase.rpc('increment_voters', {
    poll_id: pollId
  })

  if (updateError) {
    const { data: poll } = await supabase
      .from('polls')
      .select('num_voters')
      .eq('id', pollId)
      .single()

    await supabase
      .from('polls')
      .update({ num_voters: (poll?.num_voters || 0) + 1 })
      .eq('id', pollId)
  }
}

export async function updatePollStatus(pollId, status) {
  const { error } = await supabase
    .from('polls')
    .update({ status })
    .eq('id', pollId)

  if (error) throw error
}

export function generateVoterId() {
  const timestamp = Date.now()
  const random = Math.random().toString(36).substring(2, 15)
  return `voter_${timestamp}_${random}`
}
