/* Sprint 1 design fixture. No network, storage, credentials or production actions. */
'use strict';

const $ = (selector) => document.querySelector(selector);
const escapeHtml = (value) => String(value).replace(/[&<>"']/g, (char) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[char]));
const money = (value) => `BDT ${Number(value).toLocaleString('en-US', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
const areas = ['Mirpur', 'Dhanmondi', 'Uttara', 'Gulshan', 'Banani', 'Mohammadpur'];
const services = ['Electrician', 'Plumber', 'Web Developer'];
const fixtures = [
  {id: 1, name: 'Rahim Electrical Works', person: 'Rahim Uddin', initials: 'RU', service: 'Electrician', areas: ['Mirpur'], years: 8, price: 450, rating: 5, verified: true, available: true, bio: 'Safe wiring, switchboard repairs and dependable electrical care for homes and small businesses.', skills: 'Wiring, switchboards, lighting'},
  {id: 2, name: 'Karim Plumbing', person: 'Karim Hasan', initials: 'KH', service: 'Plumber', areas: ['Mirpur'], years: 12, price: 350, rating: 4, verified: true, available: true, bio: 'Leaking taps, water lines and bathroom installations. Clear estimates before every job.', skills: 'Leak repairs, pipe fitting, installations'},
  {id: 3, name: 'Sadia Web Studio', person: 'Sadia Akter', initials: 'SA', service: 'Web Developer', areas: ['Dhanmondi', 'Mirpur'], years: 5, price: 2500, rating: 5, verified: true, available: true, bio: 'Thoughtful websites for local businesses. From your first landing page to a complete online store.', skills: 'Django, Flutter, e-commerce'},
];
const freshState = () => ({
  role: 'customer', signedIn: false, page: 'discover', selected: 1,
  filter: {service: 'Electrician', area: 'Mirpur', text: ''},
  preview: 'normal', pending: null, quotes: [], draft: null,
  professionals: JSON.parse(JSON.stringify(fixtures)),
});
let state = freshState();
let noticeTimer;
const currentPro = () => state.professionals.find((pro) => pro.id === state.selected);
const ownBusiness = () => state.professionals[0];

function icon(name) {
  const paths = {
    discover: '<circle cx="12" cy="12" r="9"/><path d="m16 8-3 5-5 3 3-5z"/>',
    activity: '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 2v4m6-4v4M8 11h8m-8 4h5"/>',
    business: '<path d="M3 10h18l-2-6H5zM5 10v10h14V10M9 20v-6h6v6"/>',
    account: '<circle cx="12" cy="8" r="4"/><path d="M4 22v-3a8 8 0 0 1 16 0v3"/>',
    back: '<path d="m14 5-7 7 7 7M7 12h14"/>',
    offline: '<path d="m3 3 18 18M2 8a17 17 0 0 1 4-2m4-1a17 17 0 0 1 12 3M5 12a11 11 0 0 1 4-2m5 0a11 11 0 0 1 5 2M8 16a6 6 0 0 1 8 0M12 20h.01"/>',
  };
  return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] || paths.discover}</svg>`;
}
function button(label, action, extra = '', style = '') {
  return `<button type="button" data-action="${action}" ${extra} class="${style}">${label}</button>`;
}
function options(values, selected, allLabel = null) {
  return `${allLabel ? `<option value="">${allLabel}</option>` : ''}${values.map((value) => `<option${value === selected ? ' selected' : ''}>${escapeHtml(value)}</option>`).join('')}`;
}
function context(service, area) {
  return `<div class="context-strip"><span>${escapeHtml(service || 'All services')}</span><span>${escapeHtml(area || 'All areas')}</span></div>`;
}
function back(label, page) {
  return button(`${icon('back')}${label}`, 'page', `data-page="${page}"`, 'back');
}
function notify(message) {
  clearTimeout(noticeTimer);
  $('#announcement').textContent = message;
  noticeTimer = setTimeout(() => { $('#announcement').textContent = ''; }, 5000);
}
function go(page) {
  state.page = page;
  render();
  $('#screen').scrollTop = 0;
  $('#screen').focus({preventScroll: true});
}
function proCard(pro) {
  return `<article class="card">
    <div class="person-heading"><span class="avatar" aria-hidden="true">${pro.initials}</span><div><h3>${escapeHtml(pro.name)}</h3><p class="small muted">${escapeHtml(pro.service)} · ${escapeHtml(pro.areas.join(', '))}</p></div></div>
    ${pro.verified ? '<span class="tag">✓ Staff verified</span>' : '<span class="tag pending">Not verified</span>'}
    <div class="facts"><span>★ ${pro.rating}.0 · 1 sample review</span><span>${pro.years} years experience</span></div>
    <p class="small">From <strong>${money(pro.price)}</strong> · ${pro.available ? 'Available' : 'Requests paused'}</p>
    ${button('View profile', 'profile', `data-id="${pro.id}"`, 'secondary')}
  </article>`;
}
function discover() {
  return `<p class="eyebrow">LOCAL PEOPLE. SKILLED HANDS.</p><h2>A little help.<br>Right around here.</h2><p class="lead">Find the person who knows how.</p>
    <form id="search-form"><label for="service">What do you need?</label><select id="service" name="service">${options(services, state.filter.service, 'All services')}</select>
    <label for="area">Your area</label><select id="area" name="area">${options(areas, state.filter.area, 'All areas')}</select>
    <label for="search-text">Business or skill <span class="muted">(optional)</span></label><input id="search-text" name="text" value="${escapeHtml(state.filter.text)}" placeholder="e.g. switchboard repair" maxlength="100">
    <button type="submit">Find professionals</button></form>
    <div class="section-head"><h3>Meet a local professional</h3></div>${proCard(ownBusiness())}`;
}
function results() {
  const header = `${back('Change filters', 'discover')}<h2>Find your person.</h2>${context(state.filter.service, state.filter.area)}`;
  if (state.preview === 'loading') return `${header}<div class="empty" role="status"><div class="spinner" aria-hidden="true"></div><h3>Finding professionals…</h3><p>Loading state preview.</p>${button('Show results', 'retry')}</div>`;
  if (state.preview === 'offline') return `${header}<div class="empty">${icon('offline')}<h3>Could not connect</h3><p>Check your connection, then try again.</p>${button('Try again', 'retry')}</div>`;
  const text = state.filter.text.toLowerCase();
  const matches = state.preview === 'empty' ? [] : state.professionals.filter((pro) =>
    (!state.filter.service || pro.service === state.filter.service) &&
    (!state.filter.area || pro.areas.includes(state.filter.area)) &&
    `${pro.name} ${pro.skills} ${pro.bio}`.toLowerCase().includes(text));
  return header + (matches.length
    ? `<p class="small muted">${matches.length} ${matches.length === 1 ? 'professional' : 'professionals'} · sample results</p>${matches.map(proCard).join('')}`
    : `<div class="empty">${icon('discover')}<h3>No matches here yet</h3><p>Try another service or area, or clear your search.</p>${button('Clear filters', 'clear')}</div>`);
}
function profile() {
  const pro = currentPro();
  return `${back('Results', 'results')}<div class="person-heading"><span class="avatar">${pro.initials}</span><div><h2>${escapeHtml(pro.name)}</h2><p class="muted small">${escapeHtml(pro.person)}</p></div></div>
    ${context(pro.service, pro.areas.includes(state.filter.area) ? state.filter.area : pro.areas[0])}
    <span class="tag${pro.verified ? '' : ' pending'}">${pro.verified ? '✓ Staff verified' : 'Not verified'}</span>
    <div class="facts"><span>★ ${pro.rating}.0 · 1 sample review</span><span>${pro.years} years experience</span></div>
    <p>Starting from <strong>${money(pro.price)}</strong></p><p class="small muted">Final price depends on the work agreed.</p>
    <hr class="divider"><h3>About the business</h3><p>${escapeHtml(pro.bio)}</p><p class="small muted">${escapeHtml(pro.skills)}</p>
    <div class="card"><h3>Recent local project</h3><p class="small">${escapeHtml(pro.service)} work completed for a local customer, with a clear estimate and careful follow-up.</p><p class="small muted">Illustrative portfolio entry</p></div>
    <div class="card"><h3>A customer's experience</h3><p class="small">“Arrived on time, explained the work clearly and left everything tidy.”</p><p class="small muted">Sample review · completed service</p></div>
    ${state.role === 'customer' ? (pro.available ? button('Request quote', 'request', '', 'full spaced') : '<p class="notice spaced">This professional has paused new requests. Choose another professional or check again later.</p>') : '<p class="notice spaced">Switch to Customer to try a quote request.</p>'}`;
}
function signin() {
  return `${back('Back', state.pending === 'quote' ? 'profile' : 'account')}<h2>Keep your requests<br>in one place.</h2><p class="lead">Sign in to request a quote and see the professional's reply.</p>
    <div class="card"><h3>Try the customer account</h3><p>Nadia Rahman</p><p class="small muted">This demo continues without a password. No real account is created.</p>${button('Continue as customer', 'signin')}</div>`;
}
function quoteForm() {
  const pro = currentPro();
  const draft = state.draft?.professional === pro.id ? state.draft : null;
  return `${back('Profile', 'profile')}<h2>Request a quote</h2><p class="lead">Tell ${escapeHtml(pro.person.split(' ')[0])} what you need a hand with.</p>
    <form id="quote-form"><label for="quote-service">Service</label><select id="quote-service" name="service">${options([pro.service], pro.service)}</select>
    <label for="quote-area">Service area</label><select id="quote-area" name="area">${options(pro.areas, draft?.area || (pro.areas.includes(state.filter.area) ? state.filter.area : pro.areas[0]))}</select>
    <label for="details">Describe the work</label><textarea id="details" name="details" required maxlength="1000" placeholder="For example: the kitchen switchboard needs repairing.">${escapeHtml(draft?.details || '')}</textarea>
    <p class="small muted">The professional will reply with an estimate. This does not confirm an appointment.</p><button type="submit" class="spaced">Send quote request</button></form>`;
}
function quoteCard(quote) {
  const pro = state.professionals.find((item) => item.id === quote.professional);
  return `<article class="card"><p class="quote-id">QUOTE #Q${String(quote.id).padStart(3, '0')}</p><h3>${escapeHtml(state.role === 'professional' ? 'Nadia Rahman' : pro.name)}</h3>
    <p class="small muted">${escapeHtml(quote.service)} · ${escapeHtml(quote.area)}</p><p class="quote-body">${escapeHtml(quote.details)}</p>
    <span class="tag${quote.reply ? '' : ' pending'}">${quote.reply ? 'Estimate received' : 'Awaiting reply'}</span>
    ${quote.reply ? `<div class="answer"><strong>${money(quote.reply.amount)}</strong><p class="small">${escapeHtml(quote.reply.terms)}</p></div>` : ''}
    ${state.role === 'professional' ? button(quote.reply ? 'Update estimate' : 'Reply with estimate', 'reply', `data-id="${quote.id}"`, 'secondary') : ''}</article>`;
}
function activity() {
  if (state.role === 'customer' && !state.signedIn) return `<h2>Your activity</h2><div class="empty">${icon('activity')}<h3>Keep track of your requests</h3><p>Sign in to see quotations and replies.</p>${button('Sign in', 'auth-activity')}</div>`;
  const quotes = state.role === 'professional' ? state.quotes.filter((quote) => quote.professional === 1) : state.quotes;
  return `<p class="eyebrow">ACTIVITY / QUOTES</p><h2>${state.role === 'professional' ? 'New work starts here.' : 'Your quote requests'}</h2>
    <p class="lead">${state.role === 'professional' ? 'Review the details and send a clear estimate.' : 'Follow the conversation from request to estimate.'}</p>
    ${quotes.length ? quotes.map(quoteCard).join('') : `<div class="empty">${icon('activity')}<h3>No quote requests yet</h3><p>${state.role === 'professional' ? 'Try sending a request to Rahim from the Customer journey.' : 'Find a professional and describe the work you need.'}</p>${button(state.role === 'professional' ? 'Try customer journey' : 'Find a professional', state.role === 'professional' ? 'customer' : 'page', 'data-page="discover"')}</div>`}`;
}
function replyForm() {
  const quote = state.quotes.find((item) => item.id === state.replyId);
  return `${back('Quotes', 'activity')}<h2>Reply with an estimate</h2><p class="lead">${escapeHtml(quote.details)}</p>
    <form id="reply-form"><label for="amount">Estimated price (BDT)</label><input id="amount" name="amount" type="number" min="0.01" max="9999999.99" step="0.01" required value="${quote.reply?.amount || ''}" placeholder="750.00">
    <label for="terms">What is included?</label><textarea id="terms" name="terms" required maxlength="1000" placeholder="Explain the work, materials and any conditions.">${escapeHtml(quote.reply?.terms || '')}</textarea>
    <button type="submit">Send estimate</button></form>`;
}
function business() {
  const pro = ownBusiness();
  return `<p class="eyebrow">MY BUSINESS</p><h2>${escapeHtml(pro.name)}</h2><p class="lead">Your skills. Your local reputation.</p>
    <span class="tag${pro.verified ? '' : ' pending'}">${pro.verified ? '✓ Staff verified' : 'Not verified'}</span>
    <div class="card"><div class="switch-row"><label for="availability">Available for new requests</label><input id="availability" type="checkbox" role="switch" ${pro.available ? 'checked' : ''}></div><p class="small muted" id="availability-note">${pro.available ? 'Customers can request a quote.' : 'New requests are paused. Existing work stays in Activity.'}</p></div>
    ${button('Edit business profile', 'page', 'data-page="edit"', 'full spaced')}
    <div class="card"><h3>Your service</h3><p>${escapeHtml(pro.service)} · ${escapeHtml(pro.areas.join(', '))}</p><p class="small muted">${escapeHtml(pro.skills)}</p><p class="small">Starting from ${money(pro.price)}</p></div>
    <div class="card"><h3>Recent local project</h3><p class="small">Electrical work with a clear estimate and careful follow-up.</p><p class="small muted">Illustrative portfolio entry</p></div>
    ${button('Open quote requests', 'page', 'data-page="activity"', 'secondary full spaced')}`;
}
function editBusiness() {
  const pro = ownBusiness();
  return `${back('My business', 'business')}<h2>Edit business profile</h2><form id="business-form">
    <label for="business-name">Business name</label><input id="business-name" name="name" required maxlength="100" value="${escapeHtml(pro.name)}">
    <label for="bio">About your business</label><textarea id="bio" name="bio" required maxlength="1000">${escapeHtml(pro.bio)}</textarea>
    <label for="skills">Skills</label><input id="skills" name="skills" required maxlength="200" value="${escapeHtml(pro.skills)}">
    <label for="price">Starting price (BDT)</label><input id="price" name="price" type="number" min="0" max="9999999.99" step="0.01" required value="${pro.price}">
    <fieldset class="area-options"><legend>Service areas · choose at least one</legend>${areas.map((area, i) => `<label class="area-option" for="area-${i}"><input id="area-${i}" name="areas" type="checkbox" value="${area}" ${pro.areas.includes(area) ? 'checked' : ''}>${area}</label>`).join('')}</fieldset>
    <p class="small muted">Service: Electrician. Verification is managed by staff.</p><button type="submit" class="spaced">Save changes</button></form>`;
}
function account() {
  const signedIn = state.role !== 'customer' || state.signedIn;
  return `<h2>Your account</h2><p class="lead">${signedIn ? 'A familiar face in your community.' : 'Find skills. Connect locally.'}</p>
    <div class="card"><h3>${signedIn ? (state.role === 'professional' ? 'Rahim Uddin' : 'Nadia Rahman') : 'Welcome to SkillConnect'}</h3><p class="small muted">${signedIn ? `${state.role === 'professional' ? 'Professional' : 'Customer'} · demo account` : 'Browse freely. Sign in when you are ready to request a quote.'}</p>
    ${button(signedIn ? 'Sign out of demo' : 'Sign in', signedIn ? 'signout' : 'auth-account', '', 'secondary')}</div>`;
}
function staff() {
  const pro = ownBusiness();
  return `<p class="eyebrow">STAFF / PROCESS SKETCH</p><h2>Review a professional</h2><p class="notice">Sample decision flow. Real staff use the Django admin website. This does not perform identity verification.</p>
    <div class="card"><h3>${escapeHtml(pro.name)}</h3><p>${escapeHtml(pro.person)}</p><p class="small muted">${escapeHtml(pro.service)} · ${escapeHtml(pro.areas.join(', '))}</p><hr class="divider"><h3>Evidence checklist</h3><p class="small">Review business details, portfolio and any supporting evidence according to the agreed verification policy.</p><p class="small muted">Policy and required documents await stakeholder confirmation.</p>
    <p class="spaced"><span class="tag${pro.verified ? '' : ' pending'}">${pro.verified ? 'Staff verified' : 'Not verified'}</span></p>${button(pro.verified ? 'Mark unverified in demo' : 'Mark verified in demo', 'verify', '', 'secondary')}</div>`;
}

function render() {
  const views = {discover, results, profile, signin, quote: quoteForm, activity, reply: replyForm, business, edit: editBusiness, account, staff};
  $('#screen').innerHTML = views[state.page]();
  const tabs = state.role === 'staff' ? [['staff', 'Verification', 'account']] : [
    ['discover', 'Discover', 'discover'], ['activity', 'Activity', 'activity'],
    ...(state.role === 'professional' ? [['business', 'My business', 'business']] : []), ['account', 'Account', 'account'],
  ];
  const active = ['results', 'profile', 'quote'].includes(state.page) ? 'discover' : state.page === 'edit' ? 'business' : state.page === 'reply' ? 'activity' : state.page === 'signin' ? 'account' : state.page;
  $('#app-nav').innerHTML = tabs.map(([page, label, glyph]) => button(`${icon(glyph)}${label}`, 'page', `data-page="${page}"${page === active ? ' aria-current="page"' : ''}`, page === active ? 'active' : '')).join('');
  const steps = state.role === 'professional' ? [['business', 'Manage your business'], ['edit', 'Update profile & availability'], ['activity', 'Review requests'], ['reply', 'Send an estimate']] : state.role === 'staff' ? [['staff', 'Review business evidence'], ['decision', 'Record verification decision']] : [['discover', 'Choose a service & area'], ['results', 'Find a professional'], ['profile', 'Review their work'], ['quote', 'Request an estimate'], ['activity', 'Track the reply']];
  $('#journey').innerHTML = steps.map(([page, label]) => `<li class="${page === state.page ? 'current' : ''}"${page === state.page ? ' aria-current="step"' : ''}>${label}</li>`).join('');
  const notes = {
    discover: 'Can a customer identify the right service and area without an account?',
    results: 'Does each card offer enough evidence to choose a profile? Try the loading, empty and error states.',
    profile: 'Are verification, experience and starting price understood? Final price is agreed through a quote.',
    signin: 'The requested action continues after demo sign-in. This is a proposed navigation improvement.',
    quote: 'Try submitting an empty description, then a valid request. Service and area remain in context.',
    activity: 'Switch roles to reply as Rahim, then return as the customer to inspect the estimate.',
    reply: 'An estimate needs a positive price and clear terms. Invalid values should keep the form open.',
    business: 'Can a professional pause new requests without losing existing work?',
    edit: 'Changes update the sample business everywhere in the prototype. Verification stays staff-controlled.',
    account: 'Guest discovery remains available. Authentication protects private work in the real app.',
    staff: 'Confirm the verification policy with operations. This is a flow sketch for the separate admin surface.',
  };
  $('#review-focus').textContent = notes[state.page];
}

function switchRole(role) {
  state.role = role;
  state.pending = null;
  $('#role').value = role;
  go(role === 'professional' ? 'business' : role === 'staff' ? 'staff' : 'discover');
}
function captureDraft() {
  const form = $('#quote-form');
  if (form) state.draft = {professional: state.selected, ...Object.fromEntries(new FormData(form))};
}
document.addEventListener('click', (event) => {
  const target = event.target.closest('button[data-action]');
  if (!target) return;
  captureDraft();
  const action = target.dataset.action;
  if (action === 'page') go(target.dataset.page);
  if (action === 'profile') { state.selected = Number(target.dataset.id); go('profile'); }
  if (action === 'request') {
    if (!currentPro().available || state.role !== 'customer') return;
    state.pending = 'quote';
    go(state.signedIn ? 'quote' : 'signin');
  }
  if (action === 'signin') { state.signedIn = true; const next = state.pending || 'account'; state.pending = null; go(next); notify('Demo customer signed in.'); }
  if (action.startsWith('auth-')) { state.pending = action === 'auth-activity' ? 'activity' : 'account'; go('signin'); }
  if (action === 'signout') { state.signedIn = false; switchRole('customer'); notify('Signed out of the demo.'); }
  if (action === 'customer') switchRole('customer');
  if (action === 'reply') { state.replyId = Number(target.dataset.id); go('reply'); }
  if (action === 'verify') { ownBusiness().verified = !ownBusiness().verified; render(); notify('Sample verification decision updated.'); }
  if (action === 'retry' || action === 'clear') {
    state.preview = 'normal'; $('#preview-state').value = 'normal';
    if (action === 'clear') state.filter = {service: '', area: '', text: ''};
    go('results');
  }
});

document.addEventListener('submit', (event) => {
  const form = event.target;
  event.preventDefault();
  const data = new FormData(form);
  for (const field of form.querySelectorAll('input[required], textarea[required]')) {
    if (!field.value.trim()) { field.setCustomValidity('Please enter a value.'); field.reportValidity(); return; }
  }
  if (form.id === 'search-form') { state.filter = {service: data.get('service'), area: data.get('area'), text: data.get('text').trim()}; go('results'); }
  if (form.id === 'quote-form') {
    if (!state.signedIn || state.role !== 'customer') { state.pending = 'quote'; go('signin'); return; }
    if (!currentPro().available) { go('profile'); notify('This professional has paused new requests.'); return; }
    state.quotes.unshift({id: state.quotes.length + 1, professional: state.selected, service: data.get('service'), area: data.get('area'), details: data.get('details').trim(), reply: null});
    state.draft = null; go('activity'); notify('Sample quote request sent. Awaiting a reply.');
  }
  if (form.id === 'reply-form') {
    const quote = state.quotes.find((item) => item.id === state.replyId);
    if (state.role !== 'professional' || quote.professional !== 1) return;
    quote.reply = {amount: Number(data.get('amount')), terms: data.get('terms').trim()};
    go('activity'); notify('Sample estimate sent. Switch to Customer to view it.');
  }
  if (form.id === 'business-form') {
    const selectedAreas = data.getAll('areas');
    if (!selectedAreas.length) { const first = form.querySelector('[name=areas]'); first.setCustomValidity('Choose at least one service area.'); first.reportValidity(); return; }
    Object.assign(ownBusiness(), {name: data.get('name').trim(), bio: data.get('bio').trim(), skills: data.get('skills').trim(), price: Number(data.get('price')), areas: selectedAreas});
    go('business'); notify('Sample business profile saved.');
  }
});
document.addEventListener('input', (event) => {
  if (typeof event.target.setCustomValidity === 'function') event.target.setCustomValidity('');
  if (event.target.name === 'areas') $('#business-form [name=areas]').setCustomValidity('');
});
document.addEventListener('change', (event) => {
  if (event.target.id === 'availability') {
    ownBusiness().available = event.target.checked;
    $('#availability-note').textContent = event.target.checked ? 'Customers can request a quote.' : 'New requests are paused. Existing work stays in Activity.';
    notify(event.target.checked ? 'Available for new requests.' : 'New requests paused.');
  }
});
$('#role').addEventListener('change', (event) => { captureDraft(); switchRole(event.target.value); });
$('#preview-state').addEventListener('change', (event) => {
  state.preview = event.target.value;
  state.role = 'customer'; $('#role').value = 'customer'; go('results');
});
for (const mode of ['visual', 'wireframe']) {
  $(`#${mode}`).addEventListener('click', () => {
    document.body.classList.toggle('wireframe', mode === 'wireframe');
    $('#visual').setAttribute('aria-pressed', String(mode === 'visual'));
    $('#wireframe').setAttribute('aria-pressed', String(mode === 'wireframe'));
  });
}
$('#reset').addEventListener('click', () => {
  state = freshState(); $('#role').value = 'customer'; $('#preview-state').value = 'normal';
  document.body.classList.remove('wireframe'); $('#visual').setAttribute('aria-pressed', 'true'); $('#wireframe').setAttribute('aria-pressed', 'false');
  go('discover'); notify('Demo reset. All sample changes cleared.');
});
render();
