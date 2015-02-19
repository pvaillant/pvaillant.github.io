---
layout : layout
title : Paul's UC and Dev/Ops Blog
---

{% for post in site.posts  limit:1 %}
<article>
  <div class="entry-container">
    <div class='entry'>
      <h2><a href="{{ post.url }}">{{post.title}}</a></h2>
      <span class="postdate">{{ post.date | date: "%e %B, %Y"  }}
        {% for tag in post.tags %}
          <li><a href="/tag/{{ tag }}">{{ tag }}</a></li>
        {% endfor %}
      </span>
      {{ post.content }}
    </div>
  </div>
  <div id="page-navigation"> 
    <div class="left"> {% if post.previous.url %} <a href="{{post.previous.url}}" title="Previous Post: {{post.previous.title}}">&larr; {{post.previous.title}}</a> {% endif %} </div> 
    <div class="right"> {% if post.next.url %} <a href="{{post.next.url}}" title="next Post: {{post.next.title}}">{{post.next.title}} &rarr; </a> {% endif %} </div> 
    <div class="clear">&nbsp;</div>
  </div> 

  {% if post.comments == true %}
  <div id="disqus_thread"></div>
  <script type="text/javascript">
    (function() {
      var dsq = document.createElement('script'); dsq.type = 'text/javascript'; dsq.async = true;
      dsq.src = 'http://paulvaillant.disqus.com/embed.js';
      (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(dsq);
    })();
  </script>
  <noscript>Please enable JavaScript to view the <a href="http://disqus.com/?ref_noscript">comments powered by Disqus.</a></noscript>
  <a href="http://disqus.com" class="dsq-brlink">blog comments powered by <span class="logo-disqus">Disqus</span></a>
  {% endif %}
</article>
{% endfor %}
